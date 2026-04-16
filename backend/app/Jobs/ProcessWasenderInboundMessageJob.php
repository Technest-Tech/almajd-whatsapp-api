<?php

declare(strict_types=1);

namespace App\Jobs;

use App\Enums\DeliveryStatus;
use App\Enums\MessageDirection;
use App\Enums\MessageType;
use App\Enums\TicketPriority;
use App\Enums\TicketStatus;
use App\Models\AppNotification;
use App\Models\ClassSession;
use App\Models\Guardian;
use App\Models\Reminder;
use App\Models\Student;
use App\Models\Teacher;
use App\Models\Ticket;
use App\Models\WhatsappMessage;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

/**
 * Process an inbound WhatsApp message received from the WasenderAPI webhook.
 *
 * Wasender webhook payload structure (messages.received event):
 * {
 *   "event": "messages.received",
 *   "timestamp": 1633456789,
 *   "data": {
 *     "messages": {
 *       "key": {
 *         "id": "3EB0X123456789",
 *         "fromMe": false,
 *         "remoteJid": "201234567890@s.whatsapp.net",
 *         "cleanedSenderPn": "201234567890",
 *         "senderLid": "123456789@lid"
 *       },
 *       "messageBody": "Hello!",
 *       "message": {
 *         "conversation": "Hello!",
 *         "imageMessage": { ... }   // for media
 *       }
 *     }
 *   }
 * }
 */
class ProcessWasenderInboundMessageJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 5;
    public array $backoff = [10, 30, 60, 120, 300];

    public function __construct(
        private array $payload
    ) {
        $this->onQueue('high');
    }

    public function handle(): void
    {
        $event = $this->payload['event'] ?? '';

        // Route to appropriate handler based on event type
        match (true) {
            in_array($event, ['messages.received', 'messages.upsert'], true) => $this->handleInboundMessage(),
            $event === 'chats.update'                                        => $this->handleChatsUpdate(),
            in_array($event, ['messages.update', 'message.update'], true)    => $this->handleStatusUpdate(),
            default => Log::debug('WasenderAPI webhook: unhandled event', ['event' => $event]),
        };
    }

    // ──────────────────────────────────────────────────────────────────────────
    // chats.update → extract inbound messages and process them
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * Wasender often delivers inbound messages via "chats.update" instead of
     * "messages.received". The payload structure is:
     *
     * {
     *   "event": "chats.update",
     *   "data": {
     *     "chats": {
     *       "id": "…@lid",
     *       "messages": [
     *         {
     *           "message": {
     *             "key": { "id": "…", "fromMe": false, "remoteJid": "…@lid", "remoteJidAlt": "201…@s.whatsapp.net" },
     *             "message": { "conversation": "reply text" },
     *             "pushName": "Contact Name",
     *             "messageTimestamp": 123456789
     *           }
     *         }
     *       ]
     *     }
     *   }
     * }
     *
     * We transform each inbound message into the same structure that
     * handleInboundMessage() expects (data.messages format) and process it.
     */
    private function handleChatsUpdate(): void
    {
        $chats = $this->payload['data']['chats'] ?? null;
        if (!$chats || empty($chats['messages'])) {
            return;
        }

        foreach ($chats['messages'] as $chatMsg) {
            $msg = $chatMsg['message'] ?? null;
            if (!$msg) continue;

            $key = $msg['key'] ?? [];

            // Skip outbound messages
            if ($key['fromMe'] ?? true) continue;

            $messageId = $key['id'] ?? null;
            if (!$messageId) continue;

            // Dedup guard
            if (WhatsappMessage::where('wa_message_id', $messageId)->exists()) continue;

            // Extract phone from remoteJidAlt or remoteJid
            $phone = null;
            $remoteJidAlt = $key['remoteJidAlt'] ?? null;
            if ($remoteJidAlt && str_contains($remoteJidAlt, '@s.whatsapp.net')) {
                $phone = preg_replace('/[^0-9]/', '', explode('@', $remoteJidAlt)[0]);
            }
            if (!$phone) {
                $remoteJid = $key['remoteJid'] ?? '';
                if (str_contains($remoteJid, '@s.whatsapp.net')) {
                    $phone = preg_replace('/[^0-9]/', '', explode('@', $remoteJid)[0]);
                }
            }
            if (!$phone) continue;

            // Build a normalised payload matching what handleInboundMessage expects
            $textBody = $msg['message']['conversation']
                ?? $msg['message']['extendedTextMessage']['text']
                ?? '';

            $transformedPayload = [
                'event' => 'messages.received',
                'data'  => [
                    'messages' => [
                        'key' => [
                            'id'              => $messageId,
                            'fromMe'          => false,
                            'remoteJid'       => $remoteJidAlt ?? $key['remoteJid'] ?? '',
                            'cleanedSenderPn' => $phone,
                        ],
                        'messageBody' => $textBody,
                        'message'     => $msg['message'] ?? [],
                        'pushName'    => $msg['pushName'] ?? '',
                    ],
                ],
            ];

            // Swap payload and process through the standard inbound handler
            $originalPayload = $this->payload;
            $this->payload = $transformedPayload;
            $this->handleInboundMessage();
            $this->payload = $originalPayload;
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Inbound Message Handler
    // ──────────────────────────────────────────────────────────────────────────

    private function handleInboundMessage(): void
    {
        $messages = $this->payload['data']['messages'] ?? null;

        if (!$messages) {
            Log::warning('WasenderAPI: No messages data in payload', ['payload' => $this->payload]);
            return;
        }

        $key = $messages['key'] ?? [];

        // Skip messages we sent ourselves
        if ($key['fromMe'] ?? false) {
            return;
        }

        $messageId = $key['id'] ?? null;
        if (!$messageId) {
            Log::warning('WasenderAPI: No message ID in key', ['key' => $key]);
            return;
        }

        // Deduplication guard
        if (WhatsappMessage::where('wa_message_id', $messageId)->exists()) {
            Log::info("WasenderAPI: Duplicate message skipped: {$messageId}");
            return;
        }

        // ── Extract sender phone number ──────────────────────────────────────
        // Use cleanedSenderPn for private chats, cleanedParticipantPn for groups.
        // Do NOT use remoteJid — it may be a LID (ending in @lid).
        $senderPhone = $key['cleanedParticipantPn']   // group sender
            ?? $key['cleanedSenderPn']                 // private sender
            ?? null;

        if (!$senderPhone) {
            // Last resort: try to extract from remoteJid if it looks like a number
            $remoteJid = $key['remoteJid'] ?? '';
            $possible  = preg_replace('/[^0-9]/', '', explode('@', $remoteJid)[0] ?? '');
            $senderPhone = $possible ?: null;
        }

        if (!$senderPhone) {
            Log::warning('WasenderAPI: Could not resolve sender phone number', ['key' => $key]);
            return;
        }

        // Normalise to E.164 with leading +
        $senderPhone = str_starts_with($senderPhone, '+') ? $senderPhone : "+{$senderPhone}";

        // ── Determine recipient (our number) ─────────────────────────────────
        $ourNumber = config('whatsapp.wasender.from_number', '');

        // ── Extract unified text body ─────────────────────────────────────────
        $body = trim((string) ($messages['messageBody'] ?? ''));

        // ── Detect teacher confirmation replies ──────────────────────────────
        $this->maybeHandleTeacherConfirmation($senderPhone, $body);

        // ── Extract media ─────────────────────────────────────────────────────
        [$mediaUrl, $mediaMime, $msgType] = $this->extractMedia($messages, $messageId);

        // ── Resolve Guardian and Ticket ──────────────────────────────────────
        $phoneWithoutPlus = ltrim($senderPhone, '+');
        $guardian = Guardian::where('phone', $senderPhone)
            ->orWhere('phone', $phoneWithoutPlus)
            ->first();

        if (!$guardian) {
            $guardian = Guardian::create([
                'name'  => 'Unknown Contact',
                'phone' => $senderPhone,
            ]);
        }

        // Auto-update guardian name if still unknown
        if ($guardian->name === 'Unknown Contact') {
            $linked = Student::where('whatsapp_number', $senderPhone)->first()
                ?? Student::where('whatsapp_number', $phoneWithoutPlus)->first()
                ?? Teacher::where('whatsapp_number', $senderPhone)->first()
                ?? Teacher::where('whatsapp_number', $phoneWithoutPlus)->first();

            if ($linked) {
                $guardian->update(['name' => $linked->name]);
            }
        }

        $ticket = Ticket::where('guardian_id', $guardian->id)
            ->whereIn('status', [TicketStatus::Open, TicketStatus::Pending])
            ->latest()
            ->first();

        if (!$ticket) {
            $ticket = Ticket::create([
                'ticket_number' => Ticket::generateTicketNumber(),
                'guardian_id'   => $guardian->id,
                'status'        => TicketStatus::Open,
                'priority'      => TicketPriority::Normal,
                'channel'       => 'whatsapp',
                'subject'       => 'New WhatsApp Inquiry',
            ]);
        } elseif ($ticket->status === TicketStatus::Pending) {
            $ticket->update(['status' => TicketStatus::Open]);
        }

        // Auto-link student/teacher to ticket
        if (!$ticket->student_id && !$ticket->teacher_id) {
            $student = $guardian->students()->first()
                ?? Student::where('whatsapp_number', $senderPhone)->first();
            $teacher = Teacher::where('whatsapp_number', $senderPhone)->first();

            if ($student) {
                $ticket->update(['student_id' => $student->id]);
            } elseif ($teacher) {
                $ticket->update(['teacher_id' => $teacher->id]);
            }
        }

        // ── Resolve reply context ─────────────────────────────────────────────
        $replyToMessageId  = null;
        $quotedMsgId = $messages['message']['extendedTextMessage']['contextInfo']['stanzaId']
            ?? $messages['message']['imageMessage']['contextInfo']['stanzaId']
            ?? null;

        if ($quotedMsgId) {
            $parentMsg = WhatsappMessage::where('wa_message_id', $quotedMsgId)->first();
            if ($parentMsg) {
                $replyToMessageId = $parentMsg->id;
            }
        }

        // ── Store message ─────────────────────────────────────────────────────
        $whatsappMessage = WhatsappMessage::create([
            'wa_message_id'       => $messageId,
            'ticket_id'           => $ticket->id,
            'direction'           => MessageDirection::Inbound,
            'from_number'         => $senderPhone,
            'to_number'           => $ourNumber,
            'message_type'        => $msgType,
            'content'             => $body,
            'media_url'           => $mediaUrl,
            'media_mime_type'     => $mediaMime,
            'delivery_status'     => DeliveryStatus::Delivered,
            'reply_to_message_id' => $replyToMessageId,
            'timestamp'           => now(),
        ]);

        $ticket->update([
            'last_message_preview' => Str::limit($body ?: 'Media Message', 100),
            'last_message_at'      => now(),
            'unread_count'         => ($ticket->unread_count ?? 0) + 1,
        ]);

        // ── Notifications ─────────────────────────────────────────────────────
        $senderName = $ticket->guardian?->name ?? $senderPhone;
        $preview    = Str::limit($body ?: $this->mediaPreviewText($msgType), 80);

        AppNotification::notifyAdmins(
            type:  'message',
            title: "رسالة جديدة من {$senderName}",
            body:  $preview,
            data:  ['ticket_id' => $ticket->id, 'guardian_name' => $senderName],
        );

        // Firebase push notification
        try {
            $fcmService = \App\Services\FcmService::getInstance();
            $fcmService->sendToAllAdmins(
                title: "رسالة جديدة من {$senderName}",
                body:  $preview,
                data:  [
                    'type'      => 'message',
                    'ticket_id' => (string) $ticket->id,
                ],
            );
        } catch (\Throwable $e) {
            Log::warning('FCM push failed', ['error' => $e->getMessage()]);
        }

        // ── Real-time WebSocket event ──────────────────────────────────────────
        event(new \App\Events\TicketMessageCreated($ticket, $whatsappMessage));

        Log::info('WasenderAPI: Inbound message stored', [
            'id'   => $whatsappMessage->id,
            'from' => $senderPhone,
            'type' => $msgType->value,
        ]);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Delivery Status Update Handler
    // ──────────────────────────────────────────────────────────────────────────

    private function handleStatusUpdate(): void
    {
        // Wasender messages.update payload:
        // { "event": "messages.update", "data": { "update": { "key": { "id": "..." }, "update": { "status": 2 } } } }
        $update    = $this->payload['data']['update'] ?? [];
        $messageId = $update['key']['id'] ?? null;
        $status    = $update['update']['status'] ?? null;

        if (!$messageId || $status === null) {
            return;
        }

        // Map Wasender numeric status to our string status
        $statusString = match ((int) $status) {
            0       => 'error',
            1       => 'pending',
            2       => 'sent',
            3       => 'delivered',
            4       => 'read',
            default => 'unknown',
        };

        $message = WhatsappMessage::where('wa_message_id', $messageId)->first();

        if (!$message) {
            return;
        }

        $message->update(['delivery_status' => $statusString]);

        \App\Models\DeliveryLog::create([
            'message_id'   => $message->id,
            'status'       => $statusString,
            'bsp_response' => $this->payload,
            'attempted_at' => now(),
        ]);

        // Broadcast real-time status update (Flutter updates tick icons)
        event(new \App\Events\TicketMessageStatusUpdated($message));
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Teacher Confirmation Flow
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * If the incoming message looks like a teacher session confirmation (1/2),
     * update the class session status accordingly.
     *
     * Ported directly from ProcessTwilioInboundMessageJob — same business logic.
     */
    private function maybeHandleTeacherConfirmation(string $phone, string $body): void
    {
        $yesPhrasesInteractive = ['1', 'yes', 'yes, joined', 'yes, completed', 'نعم', 'نعم، انضم', 'نعم انضم', 'نعم، اكتملت', 'نعم اكتملت', 'yes_joined', 'yes_completed'];
        $noPhrasesInteractive  = ['2', 'no', 'no, didn\'t join', 'no, didn\'t complete', 'لا', 'لا، لم ينضم', 'لا لم ينضم', 'لا، لم تكتمل', 'لا لم تكتمل', 'no_joined', 'no_completed'];
        $ambiguousBodyOnly     = ['yes', 'no', 'نعم', 'لا'];

        $check = mb_strtolower(trim($body));

        // Reject ambiguous single-word replies to prevent accidental confirmation
        if (in_array($check, $ambiguousBodyOnly, true)) {
            return;
        }

        $normalizedReply = null;

        if (in_array($check, ['1', '٢'], true) || in_array($check, $yesPhrasesInteractive, true)) {
            $normalizedReply = '1';
        } elseif (in_array($check, ['2', '٢'], true) || in_array($check, $noPhrasesInteractive, true)) {
            $normalizedReply = '2';
        }

        if ($normalizedReply === null) {
            return;
        }

        $handled = $this->handleTeacherConfirmation($phone, $normalizedReply);

        if ($handled) {
            Log::info('WasenderAPI: Teacher confirmation applied', [
                'phone'   => $phone,
                'matched' => $check,
                'reply'   => $normalizedReply,
            ]);
        }
    }

    /**
     * Apply session status update based on teacher's confirmation reply.
     */
    private function handleTeacherConfirmation(string $phone, string $reply): bool
    {
        $reminder = Reminder::where('recipient_phone', $phone)
            ->where('recipient_type', 'teacher')
            ->where('confirmation_status', 'awaiting')
            ->where('status', 'sent')
            ->latest('sent_at')
            ->first();

        if (!$reminder || !$reminder->class_session_id) {
            return false;
        }

        $maxAgeHours = (int) config('whatsapp.teacher_confirmation_max_age_hours', 72);
        if ($reminder->sent_at && $reminder->sent_at->lt(now()->subHours($maxAgeHours))) {
            Log::warning('WasenderAPI: Teacher confirmation ignored — stale reminder', [
                'reminder_id'      => $reminder->id,
                'class_session_id' => $reminder->class_session_id,
            ]);
            return false;
        }

        $session = ClassSession::find($reminder->class_session_id);
        if (!$session || in_array($session->status, ['completed', 'cancelled'], true)) {
            return false;
        }

        $phase = $reminder->reminder_phase;

        if ($reply === '1') {
            $reminder->update(['confirmation_status' => 'confirmed']);

            if (in_array($phase, ['post_end', 'post_end_2'])) {
                $session->update(['status' => 'completed', 'attendance_status' => 'both_joined']);
            } else {
                $session->update(['status' => 'running', 'attendance_status' => 'both_joined']);
            }

            // Cancel pending pre-class reminders for this session
            Reminder::where('class_session_id', $session->id)
                ->where('status', 'pending')
                ->whereIn('reminder_phase', ['before', 'at_start', 'after'])
                ->update([
                    'status'         => 'cancelled',
                    'failure_reason' => 'Teacher confirmed — session active',
                ]);

            // Mark other awaiting reminders for same session as no_reply
            Reminder::where('class_session_id', $session->id)
                ->where('confirmation_status', 'awaiting')
                ->where('id', '!=', $reminder->id)
                ->update(['confirmation_status' => 'no_reply']);
        } else {
            $reminder->update(['confirmation_status' => 'denied']);

            if (in_array($phase, ['post_end', 'post_end_2'])) {
                $session->update(['status' => 'running']);
            } else {
                $session->update(['status' => 'pending', 'attendance_status' => 'no_show']);
            }
        }

        return true;
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Media Helpers
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * Extract media information from the Wasender message payload.
     *
     * Wasender delivers media as encrypted files. We can either:
     *   (a) Call Wasender's /api/decrypt-media endpoint, OR
     *   (b) Manually decrypt using HKDF + AES-256-CBC (matching WhatsApp protocol)
     *
     * We use strategy (a) — the Wasender decrypt API — for simplicity.
     *
     * @return array{0: ?string, 1: ?string, 2: MessageType}
     */
    private function extractMedia(array $messages, string $messageId): array
    {
        $rawMessage = $messages['message'] ?? [];
        $mediaTypes = [
            'imageMessage'    => ['image', MessageType::Image],
            'videoMessage'    => ['video', MessageType::Video],
            'audioMessage'    => ['audio', MessageType::Audio],
            'documentMessage' => ['document', MessageType::Document],
            'stickerMessage'  => ['sticker', MessageType::Image],
        ];

        foreach ($mediaTypes as $key => [$mediaType, $msgType]) {
            if (!isset($rawMessage[$key])) {
                continue;
            }

            $mediaObj  = $rawMessage[$key];
            $encUrl    = $mediaObj['url']      ?? null;
            $mediaKey  = $mediaObj['mediaKey'] ?? null;
            $mime      = $mediaObj['mimetype'] ?? null;

            if (!$encUrl || !$mediaKey) {
                // Encrypted media without keys — store the raw URL as fallback
                return [$encUrl, $mime, $msgType];
            }

            // Use Wasender decrypt API to get a public URL (valid for 1 hour)
            $publicUrl = $this->decryptMediaViaApi($encUrl, $mediaKey, $mediaType);

            if ($publicUrl) {
                // Download and store locally so we own the file permanently
                $storedUrl = $this->downloadAndStore($publicUrl, $mime ?? 'application/octet-stream', $messageId);
                return [$storedUrl ?? $publicUrl, $mime, $msgType];
            }

            return [$encUrl, $mime, $msgType];
        }

        return [null, null, MessageType::Text];
    }

    /**
     * Call Wasender's /api/decrypt-media endpoint to get a temporary public URL.
     */
    private function decryptMediaViaApi(string $url, string $mediaKey, string $mediaType): ?string
    {
        $apiKey  = config('whatsapp.wasender.api_key');
        $baseUrl = config('whatsapp.wasender.base_url', 'https://www.wasenderapi.com/api');

        try {
            $response = Http::withToken($apiKey)
                ->asJson()
                ->timeout(20)
                ->post("{$baseUrl}/decrypt-media", [
                    'url'       => $url,
                    'mediaKey'  => $mediaKey,
                    'mediaType' => $mediaType,
                ]);

            if ($response->successful()) {
                return $response->json('data.publicUrl');
            }

            Log::warning('WasenderAPI: decrypt-media failed', [
                'status' => $response->status(),
                'body'   => $response->body(),
            ]);
        } catch (\Throwable $e) {
            Log::warning('WasenderAPI: decrypt-media exception', ['error' => $e->getMessage()]);
        }

        return null;
    }

    /**
     * Download a file from the given URL and store it in public storage.
     * Returns the publicly accessible URL, or null on failure.
     */
    private function downloadAndStore(string $url, string $mime, string $messageId): ?string
    {
        try {
            $response = Http::timeout(30)->get($url);

            if (!$response->successful()) {
                return null;
            }

            $extension = $this->extensionFromMime($mime);
            $filename  = Str::ulid() . '.' . $extension;
            $path      = 'tickets/inbound/' . $filename;

            Storage::disk('public')->put($path, $response->body());

            return url(Storage::url($path));
        } catch (\Throwable $e) {
            Log::warning('WasenderAPI: Failed to download/store media', [
                'url'   => $url,
                'error' => $e->getMessage(),
            ]);
            return null;
        }
    }

    private function extensionFromMime(string $mime): string
    {
        return match (true) {
            str_contains($mime, 'jpeg')  => 'jpeg',
            str_contains($mime, 'png')   => 'png',
            str_contains($mime, 'webp')  => 'webp',
            str_contains($mime, 'gif')   => 'gif',
            str_contains($mime, 'mp4')   => 'mp4',
            str_contains($mime, 'ogg')   => 'ogg',
            str_contains($mime, 'mpeg')  => 'mp3',
            str_contains($mime, 'audio') => 'm4a',
            str_contains($mime, 'pdf')   => 'pdf',
            default                      => 'bin',
        };
    }

    private function mediaPreviewText(MessageType $type): string
    {
        return match ($type) {
            MessageType::Image    => '📷 صورة',
            MessageType::Video    => '🎥 فيديو',
            MessageType::Audio    => '🎵 صوت',
            MessageType::Document => '📄 مستند',
            default               => '📎 ملف',
        };
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Failure Handler
    // ──────────────────────────────────────────────────────────────────────────

    public function failed(\Throwable $e): void
    {
        Log::error('ProcessWasenderInboundMessageJob permanently failed', [
            'error'   => $e->getMessage(),
            'payload' => $this->payload,
        ]);
    }
}
