<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Models\ClassSession;
use App\Models\Reminder;
use App\Models\WhatsappTemplate;
use App\Services\SessionLoadBalancerService;
use App\Support\ReminderTemplateResolver;
use Carbon\Carbon;
use Illuminate\Console\Command;

class AutoScheduleRemindersCommand extends Command
{
    protected $signature = 'reminders:auto-schedule';
    protected $description = 'Auto-create WhatsApp reminders for today\'s class sessions & assign supervisors';

    public function handle(): void
    {
        // ── TEMPORARY PAUSE FOR TODAY (Requested by Admin) ───────────────
        if (now('Africa/Cairo')->toDateString() === '2026-04-24') {
            $this->info("Reminders are temporarily paused for today (2026-04-24). Will resume tomorrow.");
            return;
        }

        $academyTz = env('ACADEMY_TIMEZONE', 'Africa/Cairo');
        $todayLocal = Carbon::today($academyTz); // The local date e.g. 2026-03-15
        $now = Carbon::now('UTC');

        // Get all relevant sessions for today:
        //  1. Sessions originally scheduled for today (session_date = today)
        //  2. Rescheduled sessions whose new date (rescheduled_date) is today
        //     — these are missed by the original session_date filter!
        $sessions = ClassSession::with(['student.guardian', 'teacher'])
            ->where(function ($q) use ($todayLocal) {
                $q->where(function ($inner) use ($todayLocal) {
                    // Normal sessions: original date is today, not rescheduled
                    $inner->where('session_date', $todayLocal->toDateString())
                          ->where('status', '!=', 'rescheduled');
                })->orWhere(function ($inner) use ($todayLocal) {
                    // Rescheduled sessions: new date is today
                    $inner->where('status', 'rescheduled')
                          ->where('rescheduled_date', $todayLocal->toDateString());
                });
            })
            ->whereIn('status', ['scheduled', 'rescheduled', 'coming', 'pending', 'running'])
            ->get();

        // Load approved templates for automation (resolve by logical key + optional config name/SID)
        $approvedTemplates = WhatsappTemplate::where('status', 'approved')->get();

        // ── Round-robin supervisor assignment ──
        $this->assignSupervisors($sessions);

        // ── Transition today's 'scheduled' sessions to 'coming' (not rescheduled ones) ──
        $sessions->where('status', 'scheduled')->each(function (ClassSession $s): void {
            $s->update(['status' => 'coming']);
        });

        $created = 0;

        foreach ($sessions as $session) {
            [$sessionStart, $sessionEnd, $startTimeDisp] = $this->sessionBoundsUtc($session, $todayLocal, $academyTz);

            // ── Skip sessions that have already fully ended ───────────────────
            // Without this guard, all reminders (before/at_start/after/post_end)
            // would fire immediately for past sessions, flooding teachers & students
            // with messages about classes that already happened.
            if ($sessionEnd->isPast()) {
                continue;
            }

            $student = $session->student;
            $teacher = $session->teacher;

            $studentPhone = null;
            $studentName = null;
            if ($student) {
                $studentName = $student->name;
                $studentPhone = $student->guardian?->phone ?? $student->phone;
            }

            $teacherPhone = $teacher?->whatsapp_number;
            $teacherName = $teacher?->name ?? '';
            $zoomUrl = ReminderTemplateResolver::normalizeZoomLink($teacher?->zoom_link);
            $zoomLinkTxt = $zoomUrl !== '' ? "\n🔗 رابط الزوم: {$zoomUrl}" : '';

            // ── Phase 1: 5 min BEFORE class (still queue if we skipped earlier runs) ──
            $beforeTime = $sessionStart->copy()->subMinutes(5);
            if ($now->lt($sessionStart)) {
                $sendAt = $beforeTime->gt($now) ? $beforeTime : $now->copy();
                if ($studentPhone) {
                    // Student templates always have exactly 1 slot = zoom URL
                    $studentVars = ['1' => $zoomUrl !== '' ? $zoomUrl : 'Zoom Link'];
                    $this->queueTemplate($session, 'student', 'before', $studentPhone, $studentName, $sendAt,
                        'student_before_reminder',
                        $studentVars,
                        $approvedTemplates, "📚 تذكير: حصة *{$session->title}* ستبدأ خلال 5 دقائق\n⏰ الوقت: {$startTimeDisp}\n👨‍🏫 المعلم: {$teacherName}{$zoomLinkTxt}");
                    $created++;
                }
                if ($teacherPhone) {
                    $this->queueTemplate($session, 'teacher', 'before', $teacherPhone, $teacherName, $sendAt,
                        'teacher_before_alert',
                        [],
                        $approvedTemplates, "📚 تذكير: حصتك *{$session->title}* ستبدأ خلال 5 دقائق\n👤 الطالب: {$studentName}\nيرجى الاستعداد.");
                    $created++;
                }
            }

            // ── Phase 2: AT class start (queue until class ends so late auto-schedule still creates it) ──
            if ($now->lt($sessionEnd)) {
                $sendAt = $sessionStart->gt($now) ? $sessionStart : $now->copy();
                if ($studentPhone) {
                    // Student templates always have exactly 1 slot = zoom URL
                    $studentVars = ['1' => $zoomUrl !== '' ? $zoomUrl : 'Zoom Link'];
                    $this->queueTemplate($session, 'student', 'at_start', $studentPhone, $studentName, $sendAt,
                        'student_at_start_reminder',
                        $studentVars,
                        $approvedTemplates, "🔔 حصة *{$session->title}* تبدأ الآن!\n⏰ الوقت: {$startTimeDisp}\n👨‍🏫 المعلم: {$teacherName}\nيرجى الانضمام فوراً{$zoomLinkTxt}");
                    $created++;
                }
                if ($teacherPhone) {
                    $this->queueTemplate($session, 'teacher', 'at_start', $teacherPhone, $teacherName, $sendAt,
                        'teacher_at_start_request',
                        [],
                        $approvedTemplates, "🔔 حصة *{$session->title}* تبدأ الآن!\n👤 الطالب: {$studentName}\n\nهل انضم الطالب؟\nأرسل *1* = نعم\nأرسل *2* = لا", 'awaiting');
                    $created++;
                }
            }

            // ── Phase 3: Repeated attendance polls (T+3, T+6, T+9) ──
            //  Sent only if student hasn't been confirmed as joined yet (gated at
            //  send-time in SendSessionRemindersJob). Each poll asks the same
            //  "did the student join?" question with a unique minute-marker so
            //  webhook responses match back to the specific reminder row.
            if ($now->lt($sessionEnd)) {
                foreach ([3, 6, 9] as $offsetMin) {
                    if ($teacherPhone) {
                        $sendAt = $sessionStart->copy()->addMinutes($offsetMin);
                        $sendAt = $sendAt->gt($now) ? $sendAt : $now->copy();
                        $this->queueTemplate($session, 'teacher', "attend_{$offsetMin}m", $teacherPhone, $teacherName, $sendAt,
                            'teacher_at_start_request',
                            [],
                            $approvedTemplates,
                            "⚠️ مر {$offsetMin} دقائق على بدء حصة *{$session->title}*\n👤 الطالب: {$studentName}\n\nهل انضم الطالب؟\nأرسل *1* = نعم\nأرسل *2* = لا",
                            'awaiting');
                        $created++;
                    }
                }
            }

            // ── Phase 3b: T+10 no-show decision poll ──
            //  Asks teacher whether to end the class or wait. If "إنهاء" → cancel
            //  immediately (handled in inbound job). If "انتظار" or no reply →
            //  silent until T+15 auto_cancel.
            if ($now->lt($sessionEnd) && $teacherPhone) {
                $sendAt = $sessionStart->copy()->addMinutes(10);
                $sendAt = $sendAt->gt($now) ? $sendAt : $now->copy();
                $this->queueTemplate($session, 'teacher', 'no_show_decision', $teacherPhone, $teacherName, $sendAt,
                    'teacher_no_show_decision',
                    [],
                    $approvedTemplates,
                    "⏳ مر 10 دقائق على بدء حصة *{$session->title}*\n👤 الطالب: {$studentName}\n\nيبدو أن الطالب لم ينضم — هل تود الإنهاء؟\nأرسل *1* = إنهاء\nأرسل *2* = انتظار",
                    'awaiting');
                $created++;
            }

            // ── Phase 3c: T+15 auto-cancel notice ──
            //  Plain text, no buttons. At send time the job cancels the session
            //  and sets attendance_status = teacher_didnt_reply. Skipped if the
            //  student was confirmed as joined OR إنهاء was already clicked.
            if ($now->lt($sessionEnd) && $teacherPhone) {
                $sendAt = $sessionStart->copy()->addMinutes(15);
                $sendAt = $sendAt->gt($now) ? $sendAt : $now->copy();
                $this->queueTemplate($session, 'teacher', 'auto_cancel', $teacherPhone, $teacherName, $sendAt,
                    'teacher_auto_cancel_notice',
                    [],
                    $approvedTemplates,
                    "❌ يبدو أن الطالب لم ينضم — تم إلغاء حصة *{$session->title}*",
                    null);
                $created++;
            }

            // ── Phase 4: 5 min AFTER class END — teacher completion poll only ──
            // NOTE: The student completion message is NOT sent here.
            // It is sent by ProcessWasenderInboundMessageJob only AFTER the teacher
            // confirms YES on this poll — ensuring the student is only notified
            // when the teacher has actually verified the session is complete.
            $afterEndTime = $sessionEnd->copy()->addMinutes(5);
            if ($now->lt($sessionEnd->copy()->addDay())) {
                $sendAt = $afterEndTime->gt($now) ? $afterEndTime : $now->copy();
                if ($teacherPhone) {
                    $this->queueTemplate($session, 'teacher', 'post_end', $teacherPhone, $teacherName, $sendAt,
                        'teacher_post_end_request',
                        [],
                        $approvedTemplates, "🏁 حصة *{$session->title}* انتهى وقتها\n👤 الطالب: {$studentName}\n\nهل اكتملت الحصة بنجاح؟\nأرسل *1* = نعم، اكتملت\nأرسل *2* = لا، لم تكتمل", 'awaiting');
                    $created++;
                }
            }

            // ── Phase 5: 10 min AFTER class END — repeated completion confirmation ──
            // Only trigger if Phase 4 was explicitly denied (No)
            $afterEndTime10 = $sessionEnd->copy()->addMinutes(10);
            if ($now->lt($sessionEnd->copy()->addDay())) {
                $firstPostEndDenied = \App\Models\Reminder::where('class_session_id', $session->id)
                    ->where('reminder_phase', 'post_end')
                    ->where('confirmation_status', 'denied')
                    ->exists();

                if ($firstPostEndDenied && $teacherPhone) {
                    $sendAt = $afterEndTime10->gt($now) ? $afterEndTime10 : $now->copy();
                    $this->queueTemplate($session, 'teacher', 'post_end_2', $teacherPhone, $teacherName, $sendAt,
                        'teacher_post_end_request',
                        [],
                        $approvedTemplates, "🏁 تذكير: حصة *{$session->title}* انتهى وقتها\n👤 الطالب: {$studentName}\n\nهل اكتملت الحصة بنجاح؟\nأرسل *1* = نعم، اكتملت\nأرسل *2* = لا، ما زالت مستمرة", 'awaiting');
                    $created++;
                }
            }

        }

        $this->info("✅ Scheduled {$created} reminders for " . $sessions->count() . " sessions.");
    }

    /**
     * Session start/end in UTC plus a short local time label for template {{2}}.
     *
     * @return array{0: Carbon, 1: Carbon, 2: string}
     */
    private function sessionBoundsUtc(ClassSession $session, Carbon $todayLocal, string $academyTz): array
    {
        $dateStr = $session->session_date->format('Y-m-d');
        $startTime = $session->start_time;
        $endTime = $session->end_time;

        if ($session->status === 'rescheduled'
            && $session->rescheduled_date
            && $session->rescheduled_start_time
            && $session->rescheduled_end_time) {
            $dateStr = $session->rescheduled_date->format('Y-m-d');
            $startTime = $session->rescheduled_start_time;
            $endTime = $session->rescheduled_end_time;
        }

        $startStr = $this->formatTimeForParse($startTime);

        // ── Guard: if end_time is missing, default to start + 1 hour ──────────
        // Without this, Carbon::parse("2026-04-24 ") resolves to midnight (00:00),
        // which is before start — causing post_end reminders to fire immediately.
        if (empty(trim((string) $endTime))) {
            $endStr = Carbon::parse("{$dateStr} {$startStr}", $academyTz)->addHour()->format('H:i:s');
        } else {
            $endStr = $this->formatTimeForParse($endTime);
        }

        $sessionStart = Carbon::parse("{$dateStr} {$startStr}", $academyTz)->utc();
        $sessionEnd   = Carbon::parse("{$dateStr} {$endStr}", $academyTz)->utc();

        // Overnight class (end_time stored as TIME wraps past midnight, e.g. 22:00→00:00):
        // roll end to the next day so duration is preserved instead of collapsing to 1 hour.
        if ($sessionEnd->lte($sessionStart)) {
            $sessionEnd = $sessionEnd->copy()->addDay();
        }
        // Final safety: if still not after start (e.g. start == end), fall back to +1 hour.
        if ($sessionEnd->lte($sessionStart)) {
            $sessionEnd = $sessionStart->copy()->addHour();
        }

        $startTimeDisp = strlen($startStr) >= 5 ? substr($startStr, 0, 5) : $startStr;

        return [$sessionStart, $sessionEnd, $startTimeDisp];
    }


    private function formatTimeForParse(mixed $time): string
    {
        if ($time instanceof \DateTimeInterface) {
            return $time->format('H:i:s');
        }
        $s = trim((string) $time);
        if (preg_match('/^\d{2}:\d{2}:\d{2}/', $s)) {
            return substr($s, 0, 8);
        }
        if (preg_match('/^\d{1,2}:\d{2}$/', $s)) {
            return strlen($s) === 4 ? '0' . $s . ':00' : $s . ':00';
        }

        return $s;
    }

    /**
     * Assign supervisors to unassigned sessions using load balancer.
     */
    private function assignSupervisors($sessions): void
    {
        app(SessionLoadBalancerService::class)->distribute($sessions);
    }

    private function queueTemplate(
        ClassSession $session,
        string $recipientType,
        string $phase,
        string $phone,
        ?string $name,
        Carbon $scheduledAt,
        string $templateName,
        array $params,
        $approvedTemplates,
        string $fallbackBody,
        ?string $confirmationStatus = null
    ): void {
        $template = ReminderTemplateResolver::resolve($templateName, $approvedTemplates);
        $templateSid = $template?->content_sid;

        $body = ReminderTemplateResolver::resolveBody($template, $params, $fallbackBody);

        $this->createReminder(
            $session, $recipientType, $phase, $phone, $name, 
            $scheduledAt, $body, $templateName, $templateSid, $params, $confirmationStatus
        );
    }

    private function createReminder(
        ClassSession $session,
        string $recipientType,
        string $phase,
        string $phone,
        ?string $name,
        Carbon $scheduledAt,
        string $messageBody,
        string $templateName,
        ?string $templateSid,
        ?array $templateParams,
        ?string $confirmationStatus = null
    ): void {
        // ── Strict dedup: skip if ANY non-cancelled reminder exists for this combo ──
        $existing = Reminder::where('class_session_id', $session->id)
            ->where('recipient_type', $recipientType)
            ->where('reminder_phase', $phase)
            ->where('recipient_phone', $phone)
            ->whereNotIn('status', ['cancelled'])
            ->exists();

        if ($existing) {
            return;
        }

        // ── Skip logic based on session status & teacher confirmation ──
        $session->refresh();

        if (in_array($session->status, ['completed', 'cancelled'], true)) {
            return;
        }

        $attendanceFlowPhases = [
            'before', 'at_start', 'after',
            'attend_3m', 'attend_6m', 'attend_9m',
            'no_show_decision', 'auto_cancel',
        ];

        if (in_array($phase, $attendanceFlowPhases, true)) {
            // Pre-class phases skip if class already running; attendance-window
            // phases (attend_*, no_show_decision, auto_cancel) are meant to fire
            // *during* a running session, so don't skip on running.
            if (in_array($phase, ['before', 'at_start', 'after'], true)
                && $session->status === 'running') {
                return;
            }

            // Once attendance is confirmed (joined), don't queue any further
            // attendance-flow reminders.
            if ($session->attendance_status === 'both_joined') {
                return;
            }

            $alreadyConfirmed = Reminder::where('class_session_id', $session->id)
                ->where('confirmation_status', 'confirmed')
                ->whereIn('reminder_phase', ['before', 'at_start', 'after',
                    'attend_3m', 'attend_6m', 'attend_9m'])
                ->exists();

            if ($alreadyConfirmed) {
                return;
            }
        }

        Reminder::create([
            'type'                => 'session_reminder',
            'recipient_type'      => $recipientType,
            'reminder_phase'      => $phase,
            'class_session_id'    => $session->id,
            'recipient_phone'     => $phone,
            'recipient_name'      => $name,
            'template_name'       => $templateName,
            'template_sid'        => $templateSid,
            'template_params'     => $templateParams,
            'message_body'        => $messageBody,
            'scheduled_at'        => $scheduledAt,
            'status'              => 'pending',
            'confirmation_status' => $confirmationStatus,
        ]);
    }
}
