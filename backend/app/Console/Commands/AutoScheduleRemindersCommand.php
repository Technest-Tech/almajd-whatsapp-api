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
        $academyTz = env('ACADEMY_TIMEZONE', 'Africa/Cairo');
        $todayLocal = Carbon::today($academyTz); // The local date e.g. 2026-03-15
        $now = Carbon::now('UTC');

        // Get all relevant sessions for today that haven't been cancelled
        $sessions = ClassSession::with(['student.guardian', 'teacher'])
            ->where('session_date', $todayLocal->toDateString())
            ->whereIn('status', ['scheduled', 'rescheduled', 'coming', 'pending', 'running'])
            ->get();

        // Load approved templates for automation (resolve by logical key + optional config name/SID)
        $approvedTemplates = WhatsappTemplate::where('status', 'approved')->get();

        // ── Round-robin supervisor assignment ──
        $this->assignSupervisors($sessions);

        // ── Transition today's 'scheduled' sessions to 'coming' ──
        $sessions->where('status', 'scheduled')->each(function (ClassSession $s): void {
            $s->update(['status' => 'coming']);
        });

        $created = 0;

        foreach ($sessions as $session) {
            [$sessionStart, $sessionEnd, $startTimeDisp] = $this->sessionBoundsUtc($session, $todayLocal, $academyTz);

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
                    $studentVars = ReminderTemplateResolver::studentSessionReminderParams(
                        ReminderTemplateResolver::resolve('student_before_reminder', $approvedTemplates),
                        $session->title,
                        $startTimeDisp,
                        $teacherName,
                        $zoomUrl,
                    );
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
                    $studentVars = ReminderTemplateResolver::studentSessionReminderParams(
                        ReminderTemplateResolver::resolve('student_at_start_reminder', $approvedTemplates),
                        $session->title,
                        $startTimeDisp,
                        $teacherName,
                        $zoomUrl,
                    );
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

            // ── Phase 3: 5 min AFTER class start (don’t skip if auto-schedule ran late) ──
            $afterStartTime = $sessionStart->copy()->addMinutes(5);
            $afterPhaseExpires = $sessionStart->copy()->addHours(2);
            if ($now->lt($sessionEnd) && $now->lt($afterPhaseExpires)) {
                $sendAt = $afterStartTime->gt($now) ? $afterStartTime : $now->copy();
                if ($studentPhone) {
                    $studentVars = ReminderTemplateResolver::studentSessionReminderParams(
                        ReminderTemplateResolver::resolve('student_after_5m_alert', $approvedTemplates),
                        $session->title,
                        $startTimeDisp,
                        $teacherName,
                        $zoomUrl,
                    );
                    $this->queueTemplate($session, 'student', 'after', $studentPhone, $studentName, $sendAt,
                        'student_after_5m_alert',
                        $studentVars,
                        $approvedTemplates, "⚠️ تنبيه: حصة *{$session->title}* بدأت منذ 5 دقائق\n⏰ {$startTimeDisp}\n👨‍🏫 المعلم: {$teacherName}\nيرجى الانضمام فوراً!{$zoomLinkTxt}");
                    $created++;
                }
                // Always queue (session is still `scheduled` here); send job skips if session already completed/cancelled.
                if ($teacherPhone) {
                    $this->queueTemplate($session, 'teacher', 'after', $teacherPhone, $teacherName, $sendAt,
                        'teacher_after_5m_request',
                        [],
                        $approvedTemplates, "⚠️ تنبيه: حصة *{$session->title}* بدأت منذ 5 دقائق\n👤 الطالب: {$studentName}\n\nمرت 5 دقائق. هل انضم الطالب؟\nأرسل *1* = نعم\nأرسل *2* = لا", 'awaiting');
                    $created++;
                }
            }

            // ── Phase 4: 5 min AFTER class END — completion confirmation ──
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
        $endStr = $this->formatTimeForParse($endTime);

        $sessionStart = Carbon::parse("{$dateStr} {$startStr}", $academyTz)->utc();
        $sessionEnd = Carbon::parse("{$dateStr} {$endStr}", $academyTz)->utc();

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

        // ── Skip if teacher already confirmed for this session (any earlier phase) ──
        $alreadyConfirmed = Reminder::where('class_session_id', $session->id)
            ->where('confirmation_status', 'confirmed')
            ->exists();

        if ($alreadyConfirmed) {
            return;
        }

        // ── Skip if session already completed/cancelled/running ──
        $session->refresh();
        if (in_array($session->status, ['completed', 'cancelled', 'running'], true)) {
            return;
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
