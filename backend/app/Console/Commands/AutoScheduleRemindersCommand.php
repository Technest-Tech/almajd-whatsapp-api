<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Models\ClassSession;
use App\Models\Reminder;
use App\Models\WhatsappTemplate;
use App\Services\SessionLoadBalancerService;
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
        $now = Carbon::now(); // System UTC now

        // Get all scheduled sessions for today that haven't been cancelled
        $sessions = ClassSession::with(['student.guardian', 'teacher'])
            ->where('session_date', $todayLocal->toDateString())
            ->whereIn('status', ['scheduled', 'rescheduled', 'pending', 'running'])
            ->get();

        // Load approved templates for automation
        $templates = WhatsappTemplate::where('status', 'approved')->get()->keyBy('name');

        // ── Round-robin supervisor assignment ──
        $this->assignSupervisors($sessions);

        $created = 0;

        foreach ($sessions as $session) {
            // Parse using the local academy timezone, then convert to UTC for accurate cron comparison
            $sessionStart = Carbon::parse($todayLocal->format('Y-m-d') . ' ' . $session->start_time, $academyTz)->setTimezone('UTC');
            $sessionEnd = Carbon::parse($todayLocal->format('Y-m-d') . ' ' . $session->end_time, $academyTz)->setTimezone('UTC');

            $student = $session->student;
            $teacher = $session->teacher;

            $studentPhone = null;
            $studentName = null;
            if ($student) {
                $studentName = $student->name;
                $studentPhone = $student->guardian?->phone ?? $student->phone;
            }

            $teacherPhone = $teacher?->whatsapp_number;
            $teacherName = $teacher?->name;

            // ── Phase 1: 5 min BEFORE class ──
            $beforeTime = $sessionStart->copy()->subMinutes(5);
            $zoomLinkTxt = $teacher->zoom_link ? "\n🔗 رابط الزوم: {$teacher->zoom_link}" : "";
            
            if ($beforeTime->isAfter($now)) {
                if ($studentPhone) {
                    $this->queueTemplate($session, 'student', 'before', $studentPhone, $studentName, $beforeTime,
                        'student_before_reminder', 
                        ['1' => $session->title, '2' => $session->start_time, '3' => $teacherName ?? '', '4' => $teacher->zoom_link ?? ''], 
                        $templates, "📚 تذكير: حصة *{$session->title}* ستبدأ خلال 5 دقائق\n⏰ الوقت: {$session->start_time}\n👨‍🏫 المعلم: {$teacherName}{$zoomLinkTxt}");
                    $created++;
                }
                if ($teacherPhone) {
                    $this->queueTemplate($session, 'teacher', 'before', $teacherPhone, $teacherName, $beforeTime,
                        'teacher_before_alert', 
                        [], 
                        $templates, "📚 تذكير: حصتك *{$session->title}* ستبدأ خلال 5 دقائق\n👤 الطالب: {$studentName}\nيرجى الاستعداد.");
                    $created++;
                }
            }

            // ── Phase 2: AT class start — teacher gets confirmation request ──
            if ($sessionStart->isAfter($now)) {
                if ($studentPhone) {
                    $this->queueTemplate($session, 'student', 'at_start', $studentPhone, $studentName, $sessionStart,
                        'student_at_start_reminder', 
                        ['1' => $session->title, '2' => $teacherName ?? '', '3' => $teacher->zoom_link ?? ''], 
                        $templates, "🔔 حصة *{$session->title}* تبدأ الآن!\n👨‍🏫 المعلم: {$teacherName}\nيرجى الانضمام فوراً{$zoomLinkTxt}");
                    $created++;
                }
                if ($teacherPhone) {
                    $this->queueTemplate($session, 'teacher', 'at_start', $teacherPhone, $teacherName, $sessionStart,
                        'teacher_at_start_request', 
                        [], 
                        $templates, "🔔 حصة *{$session->title}* تبدأ الآن!\n👤 الطالب: {$studentName}\n\nهل انضم الطالب؟\nأرسل *1* = نعم\nأرسل *2* = لا", 'awaiting');
                    $created++;
                }
            }

            // ── Phase 3: 5 min AFTER class start ──
            $afterStartTime = $sessionStart->copy()->addMinutes(5);
            if ($afterStartTime->isAfter($now)) {
                if ($studentPhone) {
                    $this->queueTemplate($session, 'student', 'after', $studentPhone, $studentName, $afterStartTime,
                        'student_after_5m_alert', 
                        ['1' => $session->title, '2' => $teacherName ?? '', '3' => $teacher->zoom_link ?? ''], 
                        $templates, "⚠️ تنبيه: حصة *{$session->title}* بدأت منذ 5 دقائق\n👨‍🏫 المعلم: {$teacherName}\nيرجى الانضمام فوراً!{$zoomLinkTxt}");
                    $created++;
                }
                // Only send teacher reminder if class is still pending
                if ($teacherPhone && $session->status === 'pending') {
                    $this->queueTemplate($session, 'teacher', 'after', $teacherPhone, $teacherName, $afterStartTime,
                        'teacher_after_5m_request', 
                        [], 
                        $templates, "⚠️ تنبيه: حصة *{$session->title}* بدأت منذ 5 دقائق\n👤 الطالب: {$studentName}\n\nمرت 5 دقائق. هل انضم الطالب؟\nأرسل *1* = نعم\nأرسل *2* = لا", 'awaiting');
                    $created++;
                }
            }

            // ── Phase 4: 5 min AFTER class END — completion confirmation ──
            $afterEndTime = $sessionEnd->copy()->addMinutes(5);
            if ($afterEndTime->isAfter($now)) {
                if ($teacherPhone) {
                    $this->queueTemplate($session, 'teacher', 'post_end', $teacherPhone, $teacherName, $afterEndTime,
                        'teacher_post_end_request', 
                        [], 
                        $templates, "🏁 حصة *{$session->title}* انتهى وقتها\n👤 الطالب: {$studentName}\n\nهل اكتملت الحصة بنجاح؟\nأرسل *1* = نعم، اكتملت\nأرسل *2* = لا، لم تكتمل", 'awaiting');
                    $created++;
                }
            }

            // ── Phase 5: 15 min AFTER class start — mark waiting if no reply ──
            if ($sessionStart->copy()->addMinutes(15)->isBefore($now) && $session->status === 'pending') {
                $session->update([
                    'status' => 'waiting',
                ]);
            }
        }

        $this->info("✅ Scheduled {$created} reminders for " . $sessions->count() . " sessions.");
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
        $templates,
        string $fallbackBody,
        ?string $confirmationStatus = null
    ): void {
        $template = $templates->get($templateName);
        $templateSid = $template?->content_sid;
        
        $body = $fallbackBody;
        if ($template) {
            $body = $template->body_template;
            foreach ($params as $key => $val) {
                $body = str_replace("{{" . $key . "}}", (string)$val, $body);
            }
        }

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
        $exists = Reminder::where('class_session_id', $session->id)
            ->where('recipient_type', $recipientType)
            ->where('reminder_phase', $phase)
            ->where('recipient_phone', $phone)
            ->exists();

        if ($exists) return;

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
