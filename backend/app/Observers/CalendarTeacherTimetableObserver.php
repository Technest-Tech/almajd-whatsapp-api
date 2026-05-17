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
        $this->triggerStudentSync($timetable);
    }

    /**
     * Handle the CalendarTeacherTimetable "updated" event.
     */
    public function updated(CalendarTeacherTimetable $timetable): void
    {
        if ($timetable->isDirty('student_name') && $timetable->getOriginal('student_name')) {
            $this->syncService->syncStudentFutureDays($timetable->getOriginal('student_name'), 90);
        }
        $this->triggerStudentSync($timetable);
    }

    /**
     * Handle the CalendarTeacherTimetable "deleted" event.
     */
    public function deleted(CalendarTeacherTimetable $timetable): void
    {
        $this->triggerStudentSync($timetable);
    }

    private function triggerStudentSync(CalendarTeacherTimetable $timetable): void
    {
        if ($timetable->student_name) {
            $this->syncService->syncStudentFutureDays($timetable->student_name, 90);
        }
    }
}
