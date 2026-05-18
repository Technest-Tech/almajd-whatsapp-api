<?php

declare(strict_types=1);

namespace App\Jobs;

use App\Models\ClassSession;
use App\Services\WhatsApp\WhatsAppServiceInterface;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

/**
 * Sends a polite nudge to teachers who have not yet submitted their session
 * report after completing a session.
 *
 * Fired every hour via the scheduler (console.php).
 * Maximum 24 nudges per session (one per hour for 24 hours).
 */
class SendReportNudgeJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    /** Maximum automatic nudges per session — after this the admin must remind manually. */
    private const MAX_NUDGES = 2;

    /** Minimum minutes after last update before sending the first nudge. */
    private const NUDGE_AFTER_MINUTES = 60;

    public function __construct()
    {
        $this->onQueue('default');
    }

    public function handle(WhatsAppServiceInterface $whatsApp): void
    {
        // Find sessions that are waiting for a report and haven't been nudged
        // the maximum number of times yet.
        $sessions = ClassSession::with(['teacher', 'student'])
            ->where('status', 'completed')           // only completed — never cancelled
            ->whereIn('report_status', ['awaiting', 'confirming'])
            ->where('report_nudge_count', '<', self::MAX_NUDGES)
            ->where('updated_at', '<=', now()->subMinutes(self::NUDGE_AFTER_MINUTES))
            ->get();

        Log::channel('reminder')->info('ReportFlow[4/4] SendReportNudgeJob — sessions pending nudge', [
            'count'        => $sessions->count(),
            'max_nudges'   => self::MAX_NUDGES,
            'nudge_after'  => self::NUDGE_AFTER_MINUTES . ' min',
        ]);

        foreach ($sessions as $session) {
            try {
                $teacherPhone = $session->teacher?->whatsapp_number;

                if (!$teacherPhone) {
                    Log::channel('reminder')->warning('ReportFlow[4/4] SKIPPED — teacher has no WhatsApp number', [
                        'session_id'    => $session->id,
                        'session_title' => $session->title,
                        'teacher_id'    => $session->teacher_id,
                        'student'       => $session->student?->name,
                        'report_status' => $session->report_status,
                    ]);
                    continue;
                }

                $studentName = $session->student?->name ?? 'الطالب';
                $subject     = $session->title ?? 'الحصة';
                $timeRaw     = $session->rescheduled_start_time ?? $session->start_time;
                $timeTag     = $timeRaw ? ' (' . substr((string) $timeRaw, 0, 5) . ')' : '';
                $nudgeNum    = $session->report_nudge_count + 1;

                if ($session->report_status === 'confirming') {
                    // Teacher sent a candidate report but hasn't clicked the poll yet
                    $message = "⏰ *تذكير #$nudgeNum*\n"
                        . "يبدو أنك أرسلت تقرير حصة {$subject}{$timeTag} مع {$studentName} "
                        . "لكنك لم تؤكد إرساله للطالب بعد.\n"
                        . "يرجى الرد على استطلاع التأكيد أعلاه.";
                } else {
                    // Still awaiting the report
                    $message = "⏰ *تذكير #$nudgeNum*\n"
                        . "لم يصلنا بعد تقرير حصة {$subject}{$timeTag} مع {$studentName}.\n"
                        . "يرجى إرسال التقرير وسيتم توجيهه للطالب بعد تأكيدك.";
                }

                $whatsApp->sendText($teacherPhone, $message);

                $session->increment('report_nudge_count');

                Log::channel('reminder')->info('ReportFlow[4/4] OK — nudge sent to teacher', [
                    'session_id'    => $session->id,
                    'session_title' => $session->title,
                    'nudge_number'  => $nudgeNum,
                    'teacher'       => $teacherPhone,
                    'teacher_name'  => $session->teacher?->name,
                    'student'       => $studentName,
                    'report_status' => $session->report_status,
                    'nudges_left'   => self::MAX_NUDGES - $nudgeNum,
                ]);

            } catch (\Throwable $e) {
                Log::channel('reminder')->error('ReportFlow[4/4] FAILED — nudge send error', [
                    'session_id'    => $session->id,
                    'session_title' => $session->title,
                    'teacher'       => $session->teacher?->whatsapp_number,
                    'error'         => $e->getMessage(),
                ]);
            }
        }
    }
}
