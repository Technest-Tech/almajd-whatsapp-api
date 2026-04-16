<?php

declare(strict_types=1);

namespace App\Jobs;

use App\Enums\DeliveryStatus;
use App\Models\DeliveryLog;
use App\Models\WhatsappMessage;
use App\Services\WhatsApp\WhatsAppServiceInterface;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

class SendWhatsAppMessageJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 3;
    public array $backoff = [30, 120, 300];

    public function __construct(
        private readonly int $messageId
    ) {
        $this->onQueue('default');
    }

    /**
     * Send an outbound WhatsApp message.
     *
     * With WasenderAPI (QR-linked personal session) there is no 24-hour window
     * restriction and no Meta template approval needed — all messages are sent
     * as plain text or media regardless of when the recipient last wrote to us.
     */
    public function handle(WhatsAppServiceInterface $whatsAppService): void
    {
        $message = WhatsappMessage::find($this->messageId);

        if (!$message || $message->delivery_status === DeliveryStatus::Sent) {
            return; // Already sent or deleted
        }

        try {
            // Build reply context (Wasender supports native quoted messages)
            $replyToMessageSid = null;
            $finalContent = $message->content ?? '';

            if ($message->reply_to_message_id) {
                $sender    = $message->reply_to_sender ?? 'رسالة';
                $bodyQuote = $message->reply_to_body
                    ?: ($message->reply_to_type === 'image'    ? '📷 صورة'
                        : ($message->reply_to_type === 'audio' ? '🎵 صوت' : '📄 مستند'));
                $bodyQuote = \Illuminate\Support\Str::limit((string) $bodyQuote, 60);
                $finalContent = "💬 *رد على ({$sender}):*\n\"{$bodyQuote}\"\n\n" . $finalContent;

                $parentMessage = WhatsappMessage::find($message->reply_to_message_id);
                if ($parentMessage?->wa_message_id) {
                    $replyToMessageSid = $parentMessage->wa_message_id;
                }
            }

            // Send — no session-window check needed with Wasender
            if ($message->media_url) {
                $type = 'image';
                if ($message->message_type === \App\Enums\MessageType::Audio)    $type = 'audio';
                elseif ($message->message_type === \App\Enums\MessageType::Video)    $type = 'video';
                elseif ($message->message_type === \App\Enums\MessageType::Document) $type = 'document';

                $result = $whatsAppService->sendMedia(
                    to: $message->to_number,
                    mediaUrl: $message->media_url,
                    type: $type,
                    caption: $finalContent,
                    replyToMessageSid: $replyToMessageSid,
                );
            } else {
                // Plain text — always allowed with Wasender (no 24-h window, no template approval)
                $result = $whatsAppService->sendText(
                    to: $message->to_number,
                    message: $finalContent ?: ($message->template_name ?? ''),
                    idempotencyKey: $message->idempotency_key,
                    replyToMessageSid: $replyToMessageSid,
                );
            }

            // Update message status
            $message->update([
                'delivery_status' => DeliveryStatus::Sent,
                'wa_message_id'   => $result['message_id'] ?: $message->wa_message_id,
            ]);

            DeliveryLog::create([
                'message_id'   => $message->id,
                'status'       => DeliveryStatus::Sent,
                'bsp_response' => $result,
                'attempted_at' => now(),
            ]);

            Log::info("WhatsApp message sent", ['id' => $message->id, 'to' => $message->to_number]);

        } catch (\Throwable $e) {
            $message->increment('retry_count');

            DeliveryLog::create([
                'message_id'     => $message->id,
                'status'         => DeliveryStatus::Failed,
                'failure_reason' => $e->getMessage(),
                'attempted_at'   => now(),
            ]);

            if ($message->retry_count >= 3) {
                $message->update([
                    'delivery_status' => DeliveryStatus::Failed,
                    'failure_reason'  => $e->getMessage(),
                ]);
                Log::error("WhatsApp message permanently failed", ['id' => $message->id]);
                return; // Don't re-throw — prevent further retries
            }

            throw $e; // Re-throw to trigger Laravel queue retry with backoff
        }
    }

    /**
     * Handle final failure.
     */
    public function failed(\Throwable $e): void
    {
        $message = WhatsappMessage::find($this->messageId);
        if ($message) {
            $message->update([
                'delivery_status' => DeliveryStatus::Failed,
                'failure_reason'  => $e->getMessage(),
            ]);
        }

        Log::error('SendWhatsAppMessageJob permanently failed', [
            'message_id' => $this->messageId,
            'error'      => $e->getMessage(),
        ]);
    }
}
