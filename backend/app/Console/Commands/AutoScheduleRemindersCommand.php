<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Models\ClassSession;
use App\Models\Reminder;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Console\Command;

class AutoScheduleRemindersCommand extends Command
{
    protected $signature = 'reminders:auto-schedule';
    protected $description = 'Auto-create WhatsApp reminders for today\'s class sessions & assign supervisors';

    public function handle(): void
    {
        $today = Carbon::today();
        $now = Carbon::now();

        // Get all scheduled sessions for today that haven't been cancelled
        $sessions = ClassSession::with(['student.guardian', 'teacher'])
            ->where('session_date', $today)
            ->whereIn('status', ['scheduled', 'rescheduled', 'running'])
            ->get();

        // ── Round-robin supervisor assignment ──
        $this->assignSupervisors($sessions);

        $created = 0;

        foreach ($sessions as $session) {
            $sessionStart = Carbon::parse($today->format('Y-m-d') . ' ' . $session->start_time);
            $sessionEnd = Carbon::parse($today->format('Y-m-d') . ' ' . $session->end_time);

            $student = $session->student;
            $teacher = $session->teacher;

            $studentPhone = null;
            $studentName = null;
            if ($student) {
                $studentName = $student->name;
                $studentPhone = $student->guardian?->phone ?? $student->phone;
            }

            $teacherPhone = $teacher?->phone;
            $teacherName = $teacher?->name;

            // ── Phase 1: 5 min BEFORE class ──
            $beforeTime = $sessionStart->copy()->subMinutes(5);
            if ($beforeTime->isAfter($now)) {
                if ($studentPhone) {
                    $this->createReminder($session, 'student', 'before', $studentPhone, $studentName, $beforeTime,
                        "📚 تذكير: حصة *{$session->title}* ستبدأ خلال 5 دقائق\n⏰ الوقت: {$session->start_time}\n👨‍🏫 المعلم: {$teacherName}"
                    );
                    $created++;
                }
                if ($teacherPhone) {
                    $this->createReminder($session, 'teacher', 'before', $teacherPhone, $teacherName, $beforeTime,
                        "📚 تذكير: حصة *{$session->title}* ستبدأ خلال 5 دقائق\n⏰ الوقت: {$session->start_time}\n👤 الطالب: {$studentName}"
                    );
                    $created++;
                }
            }

            // ── Phase 2: AT class start — teacher gets confirmation request ──
            if ($sessionStart->isAfter($now)) {
                if ($studentPhone) {
                    $this->createReminder($session, 'student', 'at_start', $studentPhone, $studentName, $sessionStart,
                        "🔔 حصة *{$session->title}* تبدأ الآن!\n👨‍🏫 المعلم: {$teacherName}\nيرجى الانضمام فوراً"
                    );
                    $created++;
                }
                if ($teacherPhone) {
                    $this->createReminder($session, 'teacher', 'at_start', $teacherPhone, $teacherName, $sessionStart,
                        "🔔 حصة *{$session->title}* تبدأ الآن!\n👤 الطالب: {$studentName}\n\n✅ هل دخلت الحصة؟\nأرسل *1* = نعم\nأرسل *2* = لا",
                        'awaiting'
                    );
                    $created++;
                }
            }

            // ── Phase 3: 5 min AFTER class start ──
            $afterStartTime = $sessionStart->copy()->addMinutes(5);
            if ($afterStartTime->isAfter($now)) {
                if ($studentPhone) {
                    $this->createReminder($session, 'student', 'after', $studentPhone, $studentName, $afterStartTime,
                        "⚠️ تنبيه: حصة *{$session->title}* بدأت منذ 5 دقائق\n👨‍🏫 المعلم: {$teacherName}\nيرجى الانضمام فوراً!"
                    );
                    $created++;
                }
                if ($teacherPhone) {
                    $this->createReminder($session, 'teacher', 'after', $teacherPhone, $teacherName, $afterStartTime,
                        "⚠️ تنبيه: حصة *{$session->title}* بدأت منذ 5 دقائق\n👤 الطالب: {$studentName}\n\n✅ هل أنت في الحصة؟\nأرسل *1* = نعم\nأرسل *2* = لا",
                        'awaiting'
                    );
                    $created++;
                }
            }

            // ── Phase 4: 5 min AFTER class END — completion confirmation ──
            $afterEndTime = $sessionEnd->copy()->addMinutes(5);
            if ($afterEndTime->isAfter($now)) {
                if ($teacherPhone) {
                    $this->createReminder($session, 'teacher', 'post_end', $teacherPhone, $teacherName, $afterEndTime,
                        "🏁 حصة *{$session->title}* انتهى وقتها\n👤 الطالب: {$studentName}\n\n✅ هل اكتملت الحصة بنجاح؟\nأرسل *1* = نعم، اكتملت\nأرسل *2* = لا، لم تكتمل",
                        'awaiting'
                    );
                    $created++;
                }
            }
        }

        $this->info("✅ Scheduled {$created} reminders for " . $sessions->count() . " sessions.");
    }

    /**
     * Round-robin assign supervisors to unassigned sessions.
     */
    private function assignSupervisors($sessions): void
    {
        $unassigned = $sessions->filter(fn($s) => !$s->supervisor_id);
        if ($unassigned->isEmpty()) return;

        // Get supervisors (role: supervisor, senior_supervisor, admin)
        $supervisors = User::role(['supervisor', 'senior_supervisor', 'admin'])->pluck('id')->toArray();
        if (empty($supervisors)) return;

        $i = 0;
        foreach ($unassigned as $session) {
            $supervisorId = $supervisors[$i % count($supervisors)];
            $session->update(['supervisor_id' => $supervisorId]);
            $i++;
        }
    }

    private function createReminder(
        ClassSession $session,
        string $recipientType,
        string $phase,
        string $phone,
        ?string $name,
        Carbon $scheduledAt,
        string $messageBody,
        ?string $confirmationStatus = null,
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
            'message_body'        => $messageBody,
            'scheduled_at'        => $scheduledAt,
            'status'              => 'pending',
            'confirmation_status' => $confirmationStatus,
        ]);
    }
}
