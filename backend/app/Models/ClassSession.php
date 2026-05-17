<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ClassSession extends Model
{
    protected $fillable = [
        'schedule_entry_id', 'student_id', 'teacher_id', 'supervisor_id', 'title', 'session_date',
        'start_time', 'end_time', 'status', 'attendance_status', 'cancellation_reason',
        'rescheduled_date', 'rescheduled_start_time', 'rescheduled_end_time',
        'teacher_report', 'report_status', 'report_nudge_count',
    ];

    protected function casts(): array
    {
        return [
            'session_date' => 'date',
            'rescheduled_date' => 'date',
        ];
    }

    public function scheduleEntry(): BelongsTo
    {
        return $this->belongsTo(ScheduleEntry::class);
    }

    public function student(): BelongsTo
    {
        return $this->belongsTo(Student::class);
    }

    public function teacher(): BelongsTo
    {
        return $this->belongsTo(Teacher::class);
    }

    public function supervisor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'supervisor_id');
    }

    /**
     * Centralized reminder cleanup whenever a session status changes.
     *
     * - cancelled/completed → cancel all pending reminders
     * - rescheduled → delete pending reminders so auto-schedule recreates them
     *   at the new time on the next cron tick
     */
    protected static function booted(): void
    {
        static::updating(function (ClassSession $session) {
            if (!$session->isDirty('status')) {
                return;
            }

            $newStatus = $session->status;
            $rlog = \Illuminate\Support\Facades\Log::channel('reminder');

            if (in_array($newStatus, ['cancelled', 'completed'], true)) {
                $reason = $newStatus === 'cancelled' ? 'تم إلغاء الحصة' : 'تم إتمام الحصة';

                // Snapshot which phases will be cancelled before wiping them (for diagnostics)
                $pendingPhases = Reminder::where('class_session_id', $session->id)
                    ->where('status', 'pending')
                    ->pluck('reminder_phase')
                    ->toArray();

                $postEndBeingCancelled = in_array('post_end', $pendingPhases, true)
                    || in_array('post_end_2', $pendingPhases, true);

                // 1. Cancel all PENDING reminders — no more messages should go out
                $pendingCancelled = Reminder::where('class_session_id', $session->id)
                    ->where('status', 'pending')
                    ->update([
                        'status'         => 'cancelled',
                        'failure_reason' => $reason,
                    ]);

                // 2. Close out SENT reminders still awaiting a poll vote —
                //    prevents stale poll taps from changing session state
                $awaitingClosed = Reminder::where('class_session_id', $session->id)
                    ->where('status', 'sent')
                    ->where('confirmation_status', 'awaiting')
                    ->update(['confirmation_status' => 'no_reply']);

                $rlog->info("SESSION {$newStatus} → reminders cleaned", [
                    'session_id'        => $session->id,
                    'pending_cancelled' => $pendingCancelled,
                    'awaiting_closed'   => $awaitingClosed,
                    'cancelled_phases'  => $pendingPhases,
                    'report_status'     => $session->report_status,
                    'attendance'        => $session->attendance_status,
                ]);

                // Warn explicitly when a post_end reminder is wiped — this means the
                // report request flow will NOT run automatically for this session.
                if ($postEndBeingCancelled) {
                    $rlog->warning('ReportFlow[WARN] post_end reminder cancelled when session moved to ' . $newStatus . ' — report will NOT be requested automatically', [
                        'session_id'    => $session->id,
                        'session_title' => $session->title,
                        'report_status' => $session->report_status,
                        'attendance'    => $session->attendance_status,
                        'teacher_id'    => $session->teacher_id,
                        'student'       => $session->student?->name ?? $session->title,
                    ]);
                }
            }

            if ($newStatus === 'rescheduled') {
                $deleted = Reminder::where('class_session_id', $session->id)
                    ->where('status', 'pending')
                    ->delete();

                $rlog->info("SESSION rescheduled → pending reminders deleted", [
                    'session_id' => $session->id,
                    'deleted'    => $deleted,
                ]);
            }
        });

        // When a session is deleted, remove ALL its reminders to prevent orphans
        static::deleting(function (ClassSession $session) {
            Reminder::where('class_session_id', $session->id)->delete();
        });
    }
}
