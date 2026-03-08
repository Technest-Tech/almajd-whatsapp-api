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
     * Uses text within session window, template outside it.
     */
    public function handle(WhatsAppServiceInterface $whatsAppService): void
    {
        $message = WhatsappMessage::find($this->messageId);

        if (!$message || $message->delivery_status === DeliveryStatus::Sent) {
            return; // Already sent or deleted
        }

        try {
            $inSessionWindow = $whatsAppService->isWithinSessionWindow($message->to_number);
            
            // Resolve Twilio SID for replies
            $replyToMessageSid = null;
            $finalContent = $message->content ?? '';

            if ($message->reply_to_message_id) {
                // Determine quote text to prepend (since native Twilio WB API outbound quotes are unsupported)
                $sender = $message->reply_to_sender ?? 'رسالة';
                $bodyQuote = $message->reply_to_body ?: ($message->reply_to_type === 'image' ? '📷 صورة' : ($message->reply_to_type === 'audio' ? '🎵 صوت' : '📄 مستند'));
                $bodyQuote = \Illuminate\Support\Str::limit((string) $bodyQuote, 60);
                
                $prefix = "💬 *رد على ({$sender}):*\n\"{$bodyQuote}\"\n\n";
                // Only prepend if there's actual text content to send, or if it's a media caption
                $finalContent = $prefix . $finalContent;

                $parentMessage = WhatsappMessage::find($message->reply_to_message_id);
                if ($parentMessage && $parentMessage->wa_message_id) {
                    $replyToMessageSid = $parentMessage->wa_message_id;
                }
            }

            if ($message->media_url) {
                $type = 'image';
                if ($message->message_type === \App\Enums\MessageType::Audio) $type = 'audio';
                elseif ($message->message_type === \App\Enums\MessageType::Video) $type = 'video';
                elseif ($message->message_type === \App\Enums\MessageType::Document) $type = 'document';

                $result = $whatsAppService->sendMedia(
                    to: $message->to_number,
                    mediaUrl: $message->media_url,
                    type: $type,
                    caption: $finalContent,
                    replyToMessageSid: $replyToMessageSid
                );
            } elseif ($inSessionWindow && $finalContent) {
                $result = $whatsAppService->sendText(
                    to: $message->to_number,
                    message: $finalContent,
                    idempotencyKey: $message->idempotency_key,
                    replyToMessageSid: $replyToMessageSid
                );
            } elseif ($message->template_name) {
                $result = $whatsAppService->sendTemplate(
                    to: $message->to_number,
                    templateName: $message->template_name,
                    params: [], // Template params would be stored or passed
                );
            } else {
                // Fallback: attempt text send even outside window (BSP will reject with error)
                $result = $whatsAppService->sendText(
                    to: $message->to_number,
                    message: $message->content ?? '',
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
