<?php

declare(strict_types=1);

namespace App\Services\WhatsApp;

use App\Enums\MessageDirection;
use App\Models\WhatsappMessage;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * WasenderAPI WhatsApp driver.
 *
 * Unlike Twilio (Meta BSP), Wasender works via a QR-linked personal WhatsApp
 * session. This means:
 *   - No 24-hour session window restriction
 *   - No Meta template approval required
 *   - Flat monthly pricing — no per-message fees
 *
 * API docs: https://wasenderapi.com/api-docs
 */
class WasenderWhatsAppService implements WhatsAppServiceInterface
{
    private string $apiKey;
    private string $baseUrl;

    public function __construct()
    {
        $this->apiKey  = config('whatsapp.wasender.api_key');
        $this->baseUrl = config('whatsapp.wasender.base_url', 'https://www.wasenderapi.com/api');
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Interface Implementation
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * {@inheritdoc}
     *
     * With Wasender, there is no 24-hour session window restriction — plain text
     * can always be sent regardless of when the recipient last messaged us.
     */
    public function sendText(
        string $to,
        string $message,
        ?string $idempotencyKey = null,
        ?string $replyToMessageSid = null
    ): array {
        $payload = [
            'to'   => $this->normalizeJid($to),
            'text' => $message,
        ];

        // Native quoted/reply message support
        if ($replyToMessageSid) {
            $payload['quotedMsgId'] = $replyToMessageSid;
        }

        return $this->post('/send-message', $payload);
    }

    /**
     * {@inheritdoc}
     *
     * With Wasender, templates are purely cosmetic (local DB records).
     * There is no Meta approval gate, so we simply resolve the template body
     * and send it as a plain text message.
     */
    public function sendTemplate(
        string $to,
        string $templateName,
        array $params,
        string $language = 'ar'
    ): array {
        // Resolve the template body from the local DB
        $template = \App\Models\WhatsappTemplate::where('name', $templateName)
            ->orWhere('content_sid', $templateName) // backwards compat with old Twilio SIDs
            ->first();

        if ($template) {
            $body = $this->resolveTemplateBody($template->body_template, $params);
        } else {
            // Fallback — use the templateName itself as plain text
            $body = $this->resolveTemplateBody($templateName, $params);
            Log::warning('WasenderAPI: Template not found in DB, sending raw text', [
                'template_name' => $templateName,
            ]);
        }

        return $this->sendText($to, $body);
    }

    /**
     * {@inheritdoc}
     *
     * Wasender uses different URL fields per media type (imageUrl, videoUrl, etc.)
     */
    public function sendMedia(
        string $to,
        string $mediaUrl,
        string $type,
        ?string $caption = null,
        ?string $replyToMessageSid = null
    ): array {
        $jid = $this->normalizeJid($to);

        $payload = ['to' => $jid];

        match ($type) {
            'image'    => $payload['imageUrl']    = $mediaUrl,
            'video'    => $payload['videoUrl']    = $mediaUrl,
            'audio'    => $payload['audioUrl']    = $mediaUrl,
            'document' => $payload['documentUrl'] = $mediaUrl,
            default    => $payload['imageUrl']    = $mediaUrl, // safe fallback
        };

        if ($caption) {
            $payload['caption'] = $caption;
        }

        if ($replyToMessageSid) {
            $payload['quotedMsgId'] = $replyToMessageSid;
        }

        return $this->post('/send-message', $payload);
    }

    /**
     * {@inheritdoc}
     *
     * With Wasender there is no 24-hour session window — this always returns true.
     * The method is retained for interface compliance and to avoid breaking callers.
     */
    public function isWithinSessionWindow(string $phoneNumber): bool
    {
        // Wasender is a QR-linked personal session — no window restriction.
        return true;
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Extra Wasender-Specific Methods (beyond the base interface)
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * Send a poll message.
     *
     * @param  array<string> $options  Up to 12 poll options
     */
    public function sendPoll(string $to, string $name, array $options, int $selectableCount = 1): array
    {
        return $this->post('/send-message', [
            'to'   => $this->normalizeJid($to),
            'poll' => [
                'question'        => $name,          // Wasender field name
                'options'         => $options,
                'selectableCount' => $selectableCount,
            ],
        ]);
    }

    /**
     * Mark a received message as read (blue ticks).
     */
    public function markAsRead(string $messageId, string $chatJid): array
    {
        return $this->post('/messages/read', [
            'messageId' => $messageId,
            'chatId'    => $chatJid,
        ]);
    }

    /**
     * Send a "typing…" or "recording…" presence indicator.
     *
     * @param  string  $presence  'composing' | 'recording' | 'paused'
     */
    public function sendPresence(string $to, string $presence = 'composing'): array
    {
        return $this->post('/send-presence-update', [
            'jid'      => $this->normalizeJid($to),
            'presence' => $presence,
        ]);
    }

    /**
     * Check whether a phone number is registered on WhatsApp.
     */
    public function isOnWhatsApp(string $phone): bool
    {
        $jid = $this->normalizeJid($phone);

        try {
            $response = Http::withToken($this->apiKey)
                ->get("{$this->baseUrl}/on-whatsapp/{$jid}");

            return (bool) ($response->json('data.exists') ?? false);
        } catch (\Throwable $e) {
            Log::warning('WasenderAPI: isOnWhatsApp check failed', ['phone' => $phone, 'error' => $e->getMessage()]);
            return false;
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Helpers
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * POST to the Wasender API, parse the response, and return a normalised result.
     *
     * @return array{message_id: string, status: string}
     */
    private function post(string $endpoint, array $payload): array
    {
        $response = Http::withToken($this->apiKey)
            ->asJson()
            ->post("{$this->baseUrl}{$endpoint}", $payload);

        if ($response->successful()) {
            $data = $response->json();

            return [
                'message_id' => (string) ($data['data']['msgId'] ?? $data['data']['id'] ?? ''),
                'status'     => 'sent',
            ];
        }

        Log::error('WasenderAPI error', [
            'endpoint' => $endpoint,
            'status'   => $response->status(),
            'body'     => $response->body(),
            'payload'  => $payload,
        ]);

        throw new \RuntimeException(
            'WasenderAPI send failed [' . $response->status() . ']: ' . $response->body()
        );
    }

    /**
     * Normalise a phone number to a valid Wasender JID.
     *
     * Wasender requires the format: 201234567890@s.whatsapp.net
     * It does NOT accept E.164 (+201234567890) or plain numbers for media.
     */
    private function normalizeJid(string $to): string
    {
        // Strip any existing whatsapp: prefix (Twilio legacy)
        $to = str_replace('whatsapp:', '', $to);

        // If already a full JID, return as-is
        if (str_contains($to, '@')) {
            return $to;
        }

        // Strip leading + to get numeric-only
        $digits = ltrim($to, '+');

        return $digits . '@s.whatsapp.net';
    }

    /**
     * Replace {{1}}, {{2}}, … placeholders or named {key} placeholders in a
     * template body with the supplied params array.
     *
     * Supports both indexed (["value1", "value2"]) and named (["key" => "value"]) params.
     */
    private function resolveTemplateBody(string $body, array $params): string
    {
        if (empty($params)) {
            return $body;
        }

        // Named placeholders: {key} or {{key}}
        foreach ($params as $key => $value) {
            $body = str_replace(["{{$key}}", "{{{$key}}}"], (string) $value, $body);
        }

        // Positional placeholders: {{1}}, {{2}}, …
        $indexed = array_values($params);
        foreach ($indexed as $i => $value) {
            $pos  = $i + 1;
            $body = str_replace(["{{$pos}}", "{{{$pos}}}"], (string) $value, $body);
        }

        return $body;
    }
}
