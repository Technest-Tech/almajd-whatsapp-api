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
 * Maximum 2 nudges per session to avoid spamming the teacher.
 */
class SendReportNudgeJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    /** Maximum nudge messages to send per session before giving up. */
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
            ->where('status', 'completed')
            ->whereIn('report_status', ['awaiting', 'confirming'])
            ->where('report_nudge_count', '<', self::MAX_NUDGES)
            // Only nudge after the grace period has elapsed since the last update
            ->where('updated_at', '<=', now()->subMinutes(self::NUDGE_AFTER_MINUTES))
            ->get();

        foreach ($sessions as $session) {
            try {
                $teacherPhone = $session->teacher?->whatsapp_number;

                if (!$teacherPhone) {
                    Log::warning('ReportNudge: teacher has no WhatsApp number', ['session_id' => $session->id]);
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

                Log::info('ReportNudge: nudge sent to teacher', [
                    'session_id'   => $session->id,
                    'nudge_number' => $nudgeNum,
                    'teacher'      => $teacherPhone,
                    'status'       => $session->report_status,
                ]);

            } catch (\Throwable $e) {
                Log::warning('ReportNudge: failed to send nudge', [
                    'session_id' => $session->id,
                    'error'      => $e->getMessage(),
                ]);
            }
        }
    }
}
