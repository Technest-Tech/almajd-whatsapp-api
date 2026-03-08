<?php

declare(strict_types=1);

namespace App\Jobs;

use App\Enums\DeliveryStatus;
use App\Enums\MessageDirection;
use App\Enums\MessageType;
use App\Models\ClassSession;
use App\Models\Guardian;
use App\Models\Reminder;
use App\Models\Ticket;
use App\Models\WhatsappMessage;
use App\Services\WhatsApp\WhatsAppServiceInterface;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class SendSessionRemindersJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public function __construct()
    {
        $this->onQueue('default');
    }

    /**
     * Send pending reminders that are due.
     * Runs every minute via scheduler.
     */
    public function handle(WhatsAppServiceInterface $whatsAppService): void
    {
        $dueReminders = Reminder::where('status', 'pending')
            ->where('scheduled_at', '<=', now())
            ->limit(50)
            ->get();

        foreach ($dueReminders as $reminder) {
            try {
                // Send via WhatsApp
                $whatsAppService->sendText(
                    to: $reminder->recipient_phone,
                    message: $reminder->message_body ?? '',
                );

                $reminder->update([
                    'status'  => 'sent',
                    'sent_at' => now(),
                ]);

                // Create a WhatsApp message record so it appears in inbox
                $this->createInboxMessage($reminder);

                Log::info("Reminder #{$reminder->id} sent to {$reminder->recipient_phone}");

            } catch (\Throwable $e) {
                $reminder->update([
                    'status'         => 'failed',
                    'failure_reason' => $e->getMessage(),
                ]);

                Log::error("Reminder #{$reminder->id} failed: {$e->getMessage()}");
            }
        }
    }

    /**
     * Create a WhatsappMessage record for the reminder so it shows in inbox.
     */
    private function createInboxMessage(Reminder $reminder): void
    {
        try {
            $phone = $reminder->recipient_phone;
            $phoneWithPlus = str_starts_with($phone, '+') ? $phone : '+' . $phone;

            // Find or create guardian for this phone
            $guardian = Guardian::where('phone', $phone)
                ->orWhere('phone', $phoneWithPlus)
                ->first();

            if (!$guardian) {
                $guardian = Guardian::create([
                    'name'  => $reminder->recipient_name ?? 'Unknown',
                    'phone' => $phoneWithPlus,
                ]);
            }

            // Find or create ticket
            $ticket = Ticket::where('guardian_id', $guardian->id)
                ->whereIn('status', [\App\Enums\TicketStatus::Open, \App\Enums\TicketStatus::Pending])
                ->latest()
                ->first();

            if (!$ticket) {
                $ticket = Ticket::create([
                    'ticket_number' => Ticket::generateTicketNumber(),
                    'guardian_id'   => $guardian->id,
                    'status'        => \App\Enums\TicketStatus::Open,
                    'priority'      => \App\Enums\TicketPriority::Normal,
                    'channel'       => 'whatsapp',
                    'subject'       => 'تذكير بالحصة',
                ]);
            }

            // Create outbound message
            $twilioNumber = config('whatsapp.twilio.from_number', env('TWILIO_FROM_NUMBER'));
            $whatsappMsg = WhatsappMessage::create([
                'wa_message_id'   => 'RMD_' . Str::ulid(),
                'ticket_id'       => $ticket->id,
                'direction'       => MessageDirection::Outbound,
                'from_number'     => $twilioNumber,
                'to_number'       => $phoneWithPlus,
                'message_type'    => MessageType::Text,
                'content'         => $reminder->message_body,
                'delivery_status' => DeliveryStatus::Sent,
                'timestamp'       => now(),
            ]);

            // Update ticket preview
            $preview = Str::limit($reminder->message_body ?? 'تذكير بالحصة', 80);
            $ticket->update([
                'last_message_preview' => $preview,
                'last_message_at'      => now(),
            ]);

            // Fire event for WebSocket real-time
            event(new \App\Events\TicketMessageCreated($ticket, $whatsappMsg));

        } catch (\Throwable $e) {
            Log::warning("Failed to create inbox message for reminder #{$reminder->id}: {$e->getMessage()}");
        }
    }
}
