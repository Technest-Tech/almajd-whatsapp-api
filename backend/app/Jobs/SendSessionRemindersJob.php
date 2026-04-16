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
            ->orderBy('scheduled_at')
            ->orderByRaw("CASE reminder_phase WHEN 'before' THEN 1 WHEN 'at_start' THEN 2 WHEN 'after' THEN 3 WHEN 'post_end' THEN 4 ELSE 5 END")
            ->limit(50)
            ->get();

        foreach ($dueReminders as $reminder) {
            try {
                if ($this->shouldSkipReminder($reminder)) {
                    $reminder->update([
                        'status'         => 'cancelled',
                        'failure_reason' => 'لم يعد ينطبق على حالة الحصة',
                    ]);
                    continue;
                }

                $isTeacherConfirmation = $reminder->recipient_type === 'teacher'
                    && in_array($reminder->reminder_phase, ['at_start', 'after', 'post_end'], true);

                $pollMessageId = null;

                if ($isTeacherConfirmation && $whatsAppService instanceof \App\Services\WhatsApp\WasenderWhatsAppService) {
                    // ── Send as native WhatsApp Poll (equivalent to Twilio quick-reply buttons) ──
                    // Teacher taps their answer directly — no typing required.
                    $pollQuestion = $this->buildPollQuestion($reminder);
                    $pollResult   = $whatsAppService->sendPoll(
                        to: $reminder->recipient_phone,
                        name: $pollQuestion,
                        options: ['نعم، انضم', 'لا، لم ينضم'],
                        selectableCount: 1,
                    );

                    // Store the poll's WA message ID so we can match incoming votes
                    $pollMessageId = $pollResult['message_id'] ?? null;

                    // Also send the text body so context is clear even on older clients
                    $body = $reminder->message_body ?? '';
                    if ($body) {
                        $body .= "\n\n_يمكنك الرد بـ *1* للتأكيد أو *2* للنفي_";
                        $whatsAppService->sendText(
                            to: $reminder->recipient_phone,
                            message: $body,
                        );
                    }
                } else {
                    // ── Plain text for all other reminder types ──
                    $whatsAppService->sendText(
                        to: $reminder->recipient_phone,
                        message: $reminder->message_body ?? '',
                    );
                }

                $reminder->update([
                    'status'          => 'sent',
                    'sent_at'         => now(),
                    'poll_message_id' => $pollMessageId, // null for non-poll reminders
                ]);


                // At class start time, move session to 'pending'
                if ($reminder->reminder_phase === 'at_start') {
                    $session = $reminder->classSession;
                    if ($session && in_array($session->status, ['scheduled', 'rescheduled', 'coming'], true)) {
                        $session->update(['status' => 'pending']);
                    }
                }

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
     * Build a clear poll question based on the reminder phase.
     */
    private function buildPollQuestion(Reminder $reminder): string
    {
        $session     = $reminder->classSession;
        $studentName = $session?->student?->name ?? 'الطالب';
        $subject     = $session?->subject ?? 'الحصة';

        return match ($reminder->reminder_phase) {
            'at_start'  => "هل انضم {$studentName} إلى حصة {$subject}؟",
            'after'     => "هل اكتملت حصة {$subject} مع {$studentName}؟",
            'post_end'  => "هل أتممت حصة {$subject} مع {$studentName}؟",
            default     => "تأكيد حصة {$subject}",
        };
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
            $fromNumber = config('whatsapp.wasender.from_number', config('whatsapp.twilio.from_number', '+201554134201'));
            $whatsappMsg = WhatsappMessage::create([
                'wa_message_id'   => 'RMD_' . Str::ulid(),
                'ticket_id'       => $ticket->id,
                'direction'       => MessageDirection::Outbound,
                'from_number'     => $fromNumber,
                'to_number'       => $phoneWithPlus,
                'message_type'    => MessageType::Text,
                'content'         => $reminder->message_body ?? '',
                'delivery_status' => DeliveryStatus::Sent,
                'timestamp'       => now(),
            ]);

            // Update ticket preview
            $ticket->update([
                'last_message_preview' => Str::limit($reminder->message_body ?? 'تذكير بالحصة', 80),
                'last_message_at'      => now(),
            ]);

            // Fire event for WebSocket real-time
            event(new \App\Events\TicketMessageCreated($ticket, $whatsappMsg));

        } catch (\Throwable $e) {
            Log::warning("Failed to create inbox message for reminder #{$reminder->id}: {$e->getMessage()}");
        }
    }

    /**
     * Skip reminders that no longer make sense for the current session state.
     */
    private function shouldSkipReminder(Reminder $reminder): bool
    {
        if ($reminder->type !== 'session_reminder' || !$reminder->class_session_id) {
            return false;
        }

        $session = ClassSession::query()->find($reminder->class_session_id);
        if (!$session) {
            return true;
        }

        // Skip if session is already completed or cancelled
        if (in_array($session->status, ['completed', 'cancelled'], true)) {
            return true;
        }

        if (in_array($reminder->reminder_phase, ['before', 'at_start', 'after'])) {
            // Skip pre-class reminders if session is already running
            if ($session->status === 'running') {
                return true;
            }

            // Skip pre-class reminders if a confirmed reminder exists for this session
            $alreadyConfirmed = Reminder::where('class_session_id', $session->id)
                ->where('confirmation_status', 'confirmed')
                ->whereIn('reminder_phase', ['before', 'at_start', 'after'])
                ->exists();

            if ($alreadyConfirmed) {
                return true;
            }
        }

        // Teacher "after" only if session has moved to pending/running (at_start fired)
        if ($reminder->reminder_phase === 'after' && $reminder->recipient_type === 'teacher') {
            if (!in_array($session->status, ['pending', 'running'], true)) {
                return true;
            }
        }

        return false;
    }

}
