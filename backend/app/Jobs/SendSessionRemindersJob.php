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
                    && in_array($reminder->reminder_phase, [
                        'at_start', 'after', 'post_end', 'post_end_2',
                        'attend_3m', 'attend_6m', 'attend_9m', 'no_show_decision',
                    ], true);

                $pollMessageId = null;

                if ($isTeacherConfirmation && $whatsAppService instanceof \App\Services\WhatsApp\WasenderWhatsAppService) {
                    // ── Build the poll question ───────────────────────────────────────
                    $pollQuestion = $this->buildPollQuestion($reminder);
                    $pollOptions  = $this->buildPollOptions($reminder);

                    // CRITICAL: persist the poll question as message_body so that
                    // ProcessWasenderInboundMessageJob can match the incoming vote
                    // back to this reminder via: WHERE message_body = pollQuestion.
                    $reminder->update(['message_body' => $pollQuestion]);

                    $pollResult = $whatsAppService->sendPoll(
                        to: $reminder->recipient_phone,
                        name: $pollQuestion,
                        options: $pollOptions,
                        selectableCount: 1,
                    );

                    // Store the poll’s WA message ID so we can match incoming votes
                    $pollMessageId = $pollResult['message_id'] ?? null;

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

                // T+15 auto-cancel notice: cancel the session right after sending the
                // text. By the time we reach here the session is still uncancelled and
                // attendance was never confirmed (shouldSkipReminder gates that).
                if ($reminder->reminder_phase === 'auto_cancel') {
                    $this->applyAutoCancel($reminder);
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
     *
     * The session start time is embedded so questions are unique when the same
     * teacher has multiple sessions with the same student+subject on the same
     * day — this matters because poll-vote webhooks are matched back to the
     * reminder by question text (Wasender doesn't return a usable WhatsApp
     * message ID on send).
     */
    private function buildPollQuestion(Reminder $reminder): string
    {
        $session     = $reminder->classSession;
        $studentName = $session?->student?->name ?? 'الطالب';
        $subject     = $session?->title ?? $session?->subject ?? 'الحصة';

        // Format time as 12-hour AM/PM (e.g. 7:03 PM)
        $timeRaw = $session?->rescheduled_start_time ?? $session?->start_time;
        if ($timeRaw) {
            $t = \Carbon\Carbon::parse((string) $timeRaw);
            $timeTag = ' (' . $t->format('g:i A') . ')';
        } else {
            $timeTag = '';
        }

        return match ($reminder->reminder_phase) {
            'at_start'         => "هل انضم {$studentName} إلى حصة {$subject}{$timeTag}؟",
            'after'            => "⚠️ مر 5 دقائق على بدء حصة {$subject}{$timeTag} — هل انضم {$studentName}؟",
            'attend_3m'        => "⚠️ مر 3 دقائق على بدء حصة {$subject}{$timeTag} — هل انضم {$studentName}؟",
            'attend_6m'        => "⚠️ مر 6 دقائق على بدء حصة {$subject}{$timeTag} — هل انضم {$studentName}؟",
            'attend_9m'        => "⚠️ مر 9 دقائق على بدء حصة {$subject}{$timeTag} — هل انضم {$studentName}؟",
            'no_show_decision' => "⏳ مر 10 دقائق ولم ينضم {$studentName} لحصة {$subject}{$timeTag} — هل تود الإنهاء؟",
            'post_end'         => "هل أتممت حصة {$subject}{$timeTag} مع {$studentName}؟",
            'post_end_2'       => "هل أتممت حصة {$subject}{$timeTag} مع {$studentName}؟ (تذكير)",
            default            => "تأكيد حصة {$subject}{$timeTag}",
        };
    }

    /**
     * Poll options vary by phase. Attendance polls use yes/no; the no-show
     * decision uses finish/wait labels.
     *
     * @return array<int, string>
     */
    private function buildPollOptions(Reminder $reminder): array
    {
        return match ($reminder->reminder_phase) {
            'no_show_decision' => ['إنهاء', 'انتظار'],
            default            => ['نعم، انضم', 'لا، لم ينضم'],
        };
    }

    /**
     * Side-effect for the T+15 auto-cancel notice: cancel the session, mark
     * attendance, and tear down any other pending reminders so the inbox stops
     * polling for a class that's been auto-cancelled.
     */
    private function applyAutoCancel(Reminder $reminder): void
    {
        $session = $reminder->classSession;
        if (!$session) {
            return;
        }

        if (in_array($session->status, ['completed', 'cancelled'], true)) {
            return;
        }

        $session->update([
            'status'              => 'cancelled',
            'attendance_status'   => 'teacher_didnt_reply',
            'cancellation_reason' => 'لم يرد المعلم على استطلاعات الحضور خلال 15 دقيقة من بدء الحصة',
        ]);

        Reminder::where('class_session_id', $session->id)
            ->where('id', '!=', $reminder->id)
            ->where('status', 'pending')
            ->update([
                'status'         => 'cancelled',
                'failure_reason' => 'تم إلغاء الحصة تلقائياً (auto_cancel)',
            ]);

        Log::info('Auto-cancel applied', [
            'session_id'  => $session->id,
            'reminder_id' => $reminder->id,
        ]);
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
                // Determine session supervisor for this reminder
                $sessionSupervisorId = $reminder->classSession?->supervisor_id;

                $ticket = Ticket::create([
                    'ticket_number'        => Ticket::generateTicketNumber(),
                    'guardian_id'          => $guardian->id,
                    'status'               => \App\Enums\TicketStatus::Open,
                    'priority'             => \App\Enums\TicketPriority::Normal,
                    'channel'              => 'whatsapp',
                    'subject'              => 'تذكير بالحصة',
                    'session_supervisor_id' => $sessionSupervisorId,
                ]);
            } elseif (!$ticket->session_supervisor_id && $reminder->classSession?->supervisor_id) {
                // Back-fill supervisor on existing ticket if missing
                $ticket->update(['session_supervisor_id' => $reminder->classSession->supervisor_id]);
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

        // ── Attendance-flow gates (attend_3m/6m/9m + no_show_decision + auto_cancel) ──
        // Skip the entire flow once the teacher has confirmed the student joined
        // (attendance_status='both_joined' is set by ProcessWasenderInboundMessageJob
        // on any YES vote to at_start / attend_*).
        $attendanceFlowPhases = ['attend_3m', 'attend_6m', 'attend_9m', 'no_show_decision', 'auto_cancel'];
        if (in_array($reminder->reminder_phase, $attendanceFlowPhases, true)) {
            if ($session->attendance_status === 'both_joined') {
                return true;
            }
        }

        // ── post_end / post_end_2: only fire if the student actually joined. ──
        // If attendance was never confirmed, there's no class to ask about.
        if (in_array($reminder->reminder_phase, ['post_end', 'post_end_2'], true)) {
            if ($session->attendance_status !== 'both_joined') {
                return true;
            }
        }

        return false;
    }

}
