<?php

namespace App\Observers;

use App\Models\CalendarStudentStop;
use App\Services\LegacyCalendarSyncService;

class CalendarStudentStopObserver
{
    protected $syncService;

    public function __construct(LegacyCalendarSyncService $syncService)
    {
        $this->syncService = $syncService;
    }

    public function created(CalendarStudentStop $stop): void
    {
        $this->syncService->syncStopsForStudent(
            $stop->student_name,
            $stop->date_from->format('Y-m-d'),
            $stop->date_to->format('Y-m-d')
        );
    }

    public function updated(CalendarStudentStop $stop): void
    {
        $this->syncService->syncStopsForStudent(
            $stop->student_name,
            $stop->date_from->format('Y-m-d'),
            $stop->date_to->format('Y-m-d')
        );
    }
}
