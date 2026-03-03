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
use Illuminate\Support\Facades\Log;
use Carbon\Carbon;

class GenerateSessionsJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public function __construct(
        private readonly int $daysAhead = 7
    ) {
        $this->onQueue('default');
    }

    /**
     * Generate class sessions from active schedule entries for the upcoming week.
     * Runs daily via scheduler.
     */
    public function handle(): void
    {
        $entries = ScheduleEntry::whereHas('schedule', fn ($q) => $q->where('is_active', true))
            ->get();

        $startDate = now()->startOfDay();
        $endDate   = now()->addDays($this->daysAhead)->endOfDay();
        $generated = 0;

        foreach ($entries as $entry) {
            $date = $startDate->copy();

            while ($date->lte($endDate)) {
                if ($date->dayOfWeek === $entry->day_of_week) {
                    // Skip if session already exists for this entry + date
                    $exists = ClassSession::where('schedule_entry_id', $entry->id)
                        ->where('session_date', $date->toDateString())
                        ->exists();

                    if (!$exists) {
                        ClassSession::create([
                            'schedule_entry_id' => $entry->id,
                            'teacher_id'        => $entry->teacher_id,
                            'title'             => $entry->title,
                            'session_date'      => $date->toDateString(),
                            'start_time'        => $entry->start_time,
                            'end_time'          => $entry->end_time,
                            'status'            => 'scheduled',
                        ]);
                        $generated++;
                    }
                }

                $date->addDay();
            }
        }

        Log::info("GenerateSessionsJob: created {$generated} sessions for next {$this->daysAhead} days");
    }
}
