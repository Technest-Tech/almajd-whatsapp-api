<?php

declare(strict_types=1);

namespace App\Services\WhatsApp;

use App\Enums\DeliveryStatus;
use App\Enums\MessageDirection;
use App\Models\DeliveryLog;
use App\Models\WhatsappMessage;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class TwilioWhatsAppService implements WhatsAppServiceInterface
{
    private string $accountSid;
    private string $authToken;
    private string $fromNumber;

    public function __construct()
    {
        $this->accountSid = config('whatsapp.twilio.account_sid');
        $this->authToken  = config('whatsapp.twilio.auth_token');
        $this->fromNumber = config('whatsapp.twilio.from_number');
    }

    /**
     * {@inheritdoc}
     */
    public function sendText(string $to, string $message, ?string $idempotencyKey = null): array
    {
        $response = Http::withBasicAuth($this->accountSid, $this->authToken)
            ->asForm()
            ->post("https://api.twilio.com/2010-04-01/Accounts/{$this->accountSid}/Messages.json", [
                'From' => "whatsapp:{$this->fromNumber}",
                'To'   => "whatsapp:{$to}",
                'Body' => $message,
            ]);

        return $this->processResponse($response);
    }

    /**
     * {@inheritdoc}
     */
    public function sendTemplate(string $to, string $templateName, array $params, string $language = 'ar'): array
    {
        // Twilio uses ContentSid for templates
        // For now, we send the resolved template body as text if within window
        // Or use ContentSid when configured
        $response = Http::withBasicAuth($this->accountSid, $this->authToken)
            ->asForm()
            ->post("https://api.twilio.com/2010-04-01/Accounts/{$this->accountSid}/Messages.json", [
                'From'       => "whatsapp:{$this->fromNumber}",
                'To'         => "whatsapp:{$to}",
                'ContentSid' => $templateName, // Twilio template SID
                'ContentVariables' => json_encode($params),
            ]);

        return $this->processResponse($response);
    }

    /**
     * {@inheritdoc}
     */
    public function sendMedia(string $to, string $mediaUrl, string $type, ?string $caption = null): array
    {
        $payload = [
            'From'     => "whatsapp:{$this->fromNumber}",
            'To'       => "whatsapp:{$to}",
            'MediaUrl' => $mediaUrl,
        ];

        if ($caption) {
            $payload['Body'] = $caption;
        }

        $response = Http::withBasicAuth($this->accountSid, $this->authToken)
            ->asForm()
            ->post("https://api.twilio.com/2010-04-01/Accounts/{$this->accountSid}/Messages.json", $payload);

        return $this->processResponse($response);
    }

    /**
     * {@inheritdoc}
     */
    public function isWithinSessionWindow(string $phoneNumber): bool
    {
        $lastInbound = WhatsappMessage::where('from_number', $phoneNumber)
            ->where('direction', MessageDirection::Inbound)
            ->latest('timestamp')
            ->first();

        if (!$lastInbound) {
            return false;
        }

        $windowHours = config('whatsapp.session_window_hours', 24);

        return $lastInbound->timestamp->diffInHours(now()) < $windowHours;
    }

    /**
     * Process the Twilio API response.
     */
    private function processResponse($response): array
    {
        if ($response->successful()) {
            $data = $response->json();
            return [
                'message_id' => $data['sid'] ?? '',
                'status'     => 'sent',
            ];
        }

        Log::error('Twilio WhatsApp API error', [
            'status' => $response->status(),
            'body'   => $response->body(),
        ]);

        throw new \RuntimeException('WhatsApp send failed: ' . $response->body());
    }
}
