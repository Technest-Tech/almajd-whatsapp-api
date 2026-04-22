<?php

namespace App\Observers;

use App\Models\CalendarTeacherTimetable;
use App\Services\LegacyCalendarSyncService;

class CalendarTeacherTimetableObserver
{
    protected $syncService;

    public function __construct(LegacyCalendarSyncService $syncService)
    {
        $this->syncService = $syncService;
    }

    /**
     * Handle the CalendarTeacherTimetable "created" event.
     */
    public function created(CalendarTeacherTimetable $timetable): void
    {
        $this->triggerSync();
    }

    /**
     * Handle the CalendarTeacherTimetable "updated" event.
     */
    public function updated(CalendarTeacherTimetable $timetable): void
    {
        $this->triggerSync();
    }

    /**
     * Handle the CalendarTeacherTimetable "deleted" event.
     */
    public function deleted(CalendarTeacherTimetable $timetable): void
    {
        // For simple bridging, regenerating the upcoming 7 days implicitly deletes missing ones if we built it that way
        // Or we just update statuses. In our bridge, we rely on the command.
        // A deletion in timetable doesn't perfectly map to class_session deletion directly unless we do exact matching.
        // We'll let stops handle mass cancellations. 
    }

    private function triggerSync(): void
    {
        // Sync the next 7 days immediately so the front-facing class_sessions table reflects this change
        $this->syncService->syncFutureDays(7);
    }
}
