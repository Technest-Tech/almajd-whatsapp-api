<?php

declare(strict_types=1);

namespace App\Jobs;

use App\Models\ClassSession;
use App\Models\ScheduleEntry;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

/**
 * Propagates ScheduleEntry changes to all upcoming 'scheduled' class sessions.
 * 
 * Rules:
 * - Only updates sessions with status = 'scheduled' (preserves rescheduled/cancelled)
 * - Only updates sessions from TODAY onwards
 * - Updates: title, start_time, end_time, teacher_id
 */
class PropagateScheduleEntryChangesJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 3;
    public int $backoff = 10;

    public function __construct(
        public readonly int $scheduleEntryId,
        public readonly string $title,
        public readonly string $startTime,
        public readonly string $endTime,
        public readonly ?int $teacherId,
    ) {}

    public function handle(): void
    {
        ClassSession::where('schedule_entry_id', $this->scheduleEntryId)
            ->where('session_date', '>=', now()->toDateString())
            ->where('status', 'scheduled') // ← preserve manually rescheduled/cancelled sessions
            ->update([
                'title'      => $this->title,
                'start_time' => $this->startTime,
                'end_time'   => $this->endTime,
                'teacher_id' => $this->teacherId,
            ]);
    }
}
