<?php

declare(strict_types=1);

namespace App\Jobs;

use App\Enums\DeliveryStatus;
use App\Enums\MessageDirection;
use App\Enums\MessageType;
use App\Models\WhatsappMessage;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

class ProcessTwilioInboundMessageJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 5;
    public array $backoff = [10, 30, 60, 120, 300];

    public function __construct(
        private readonly array $payload
    ) {
        $this->onQueue('high');
    }

    /**
     * Process inbound Twilio Sandbox message.
     */
    public function handle(): void
    {
        $messageSid = $this->payload['MessageSid'] ?? null;
        
        if (!$messageSid) {
            Log::warning("Twilio Webhook: No MessageSid found in payload.", ['payload' => $this->payload]);
            return;
        }

        // Avoid duplicate reprocessing
        if (WhatsappMessage::where('wa_message_id', $messageSid)->exists()) {
            Log::info("Twilio Webhook: Duplicate message skipped: {$messageSid}");
            return;
        }

        $fromNumber = $this->payload['From'] ?? '';       // Expected format: whatsapp:+1234567890
        $toNumber   = $this->payload['To'] ?? '';         // Expected format: whatsapp:+14155238886
        $body       = $this->payload['Body'] ?? '';
        $numMedia   = (int) ($this->payload['NumMedia'] ?? 0);
        
        // Clean Twilio 'whatsapp:' prefix securely
        $fromNumber = str_replace('whatsapp:', '', $fromNumber);
        $toNumber   = str_replace('whatsapp:', '', $toNumber);

        // Normalize Media
        $mediaUrl   = null;
        $mediaMime  = null;
        $msgType    = MessageType::Text;

        if ($numMedia > 0) {
            $mediaUrl  = $this->payload['MediaUrl0'] ?? null;
            $mediaMime = $this->payload['MediaContentType0'] ?? null;
            
            // Guess type roughly by mime
            if (str_starts_with((string)$mediaMime, 'image/')) {
                $msgType = MessageType::Image;
            } elseif (str_starts_with((string)$mediaMime, 'video/')) {
                $msgType = MessageType::Video;
            } elseif (str_starts_with((string)$mediaMime, 'audio/')) {
                $msgType = MessageType::Audio;
            } else {
                $msgType = MessageType::Document;
            }
        }

        // For templates injected by sandbox API
        if (!empty($this->payload['ContentSid'])) {
             $msgType = MessageType::Template;
        }

        // Store the final structured message
        $whatsappMessage = WhatsappMessage::create([
            'wa_message_id'   => $messageSid,
            'direction'       => MessageDirection::Inbound,
            'from_number'     => $fromNumber,
            'to_number'       => $toNumber,
            'message_type'    => $msgType,
            'content'         => $body,
            'media_url'       => $mediaUrl,
            'media_mime_type' => $mediaMime,
            'delivery_status' => DeliveryStatus::Delivered,
            'timestamp'       => now(),
        ]);

        Log::info("Inbound Twilio message stored", [
            'id'   => $whatsappMessage->id,
            'from' => $fromNumber,
            'type' => $msgType->value,
        ]);

        // Trigger Event for frontend WebSockets or Kanban updates (Week 4 logic)
        // event(new \App\Events\MessageReceived($whatsappMessage));
    }

    public function failed(\Throwable $e): void
    {
        Log::error('ProcessTwilioInboundMessageJob failed', [
            'error'   => $e->getMessage(),
            'payload' => $this->payload,
        ]);
    }
}
