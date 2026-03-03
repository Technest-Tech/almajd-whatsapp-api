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

class ProcessInboundMessageJob implements ShouldQueue
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
     * Process inbound WhatsApp message:
     * 1. Parse BSP payload
     * 2. Store WhatsappMessage
     * 3. Resolve guardian contact
     * 4. Create or attach to ticket (done in Week 4 via events)
     * 5. Broadcast event
     */
    public function handle(): void
    {
        $messages = data_get($this->payload, 'entry.0.changes.0.value.messages', []);
        $contacts = data_get($this->payload, 'entry.0.changes.0.value.contacts', []);
        $metadata = data_get($this->payload, 'entry.0.changes.0.value.metadata', []);

        foreach ($messages as $index => $msg) {
            $wamid = $msg['id'] ?? null;
            if (!$wamid) {
                continue;
            }

            // Skip if already stored (belt + suspenders with middleware idempotency)
            if (WhatsappMessage::where('wa_message_id', $wamid)->exists()) {
                Log::info("Duplicate wamid skipped in job: {$wamid}");
                continue;
            }

            $from       = $msg['from'] ?? '';
            $to         = $metadata['display_phone_number'] ?? '';
            $type       = $msg['type'] ?? 'text';
            $timestamp  = isset($msg['timestamp']) ? \Carbon\Carbon::createFromTimestamp($msg['timestamp']) : now();
            $content    = null;
            $mediaUrl   = null;
            $mediaMime  = null;

            // Extract content based on type
            switch ($type) {
                case 'text':
                    $content = $msg['text']['body'] ?? '';
                    break;
                case 'image':
                case 'video':
                case 'audio':
                case 'document':
                    $mediaData = $msg[$type] ?? [];
                    $content   = $mediaData['caption'] ?? null;
                    $mediaUrl  = $mediaData['id'] ?? null; // BSP media ID — download separately
                    $mediaMime = $mediaData['mime_type'] ?? null;
                    break;
            }

            // Store the message
            $whatsappMessage = WhatsappMessage::create([
                'wa_message_id'   => $wamid,
                'direction'       => MessageDirection::Inbound,
                'from_number'     => '+' . ltrim($from, '+'),
                'to_number'       => '+' . ltrim($to, '+'),
                'message_type'    => MessageType::tryFrom($type) ?? MessageType::Text,
                'content'         => $content,
                'media_url'       => $mediaUrl,
                'media_mime_type' => $mediaMime,
                'delivery_status' => DeliveryStatus::Delivered,
                'timestamp'       => $timestamp,
            ]);

            Log::info("Inbound WhatsApp message stored", [
                'id'   => $whatsappMessage->id,
                'from' => $from,
                'type' => $type,
            ]);

            // TODO (Week 4): Resolve guardian → create/attach ticket
            // event(new \App\Events\MessageReceived($whatsappMessage));
        }
    }

    /**
     * Handle job failure.
     */
    public function failed(\Throwable $e): void
    {
        Log::error('ProcessInboundMessageJob failed', [
            'error'   => $e->getMessage(),
            'payload' => array_keys($this->payload),
        ]);
    }
}
