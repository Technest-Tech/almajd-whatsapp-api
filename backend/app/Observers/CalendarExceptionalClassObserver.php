<?php

namespace App\Observers;

use App\Models\CalendarExceptionalClass;
use App\Services\LegacyCalendarSyncService;
use Carbon\Carbon;

class CalendarExceptionalClassObserver
{
    protected $syncService;

    public function __construct(LegacyCalendarSyncService $syncService)
    {
        $this->syncService = $syncService;
    }

    public function created(CalendarExceptionalClass $exceptionalClass): void
    {
        $this->triggerStudentSync($exceptionalClass);
    }

    public function updated(CalendarExceptionalClass $exceptionalClass): void
    {
        if ($exceptionalClass->isDirty('student_name') && $exceptionalClass->getOriginal('student_name')) {
            $this->syncService->syncStudentFutureDays($exceptionalClass->getOriginal('student_name'), 90);
        }
        $this->triggerStudentSync($exceptionalClass);
    }

    public function deleted(CalendarExceptionalClass $exceptionalClass): void
    {
        $this->triggerStudentSync($exceptionalClass);
    }

    private function triggerStudentSync(CalendarExceptionalClass $exceptionalClass): void
    {
        if ($exceptionalClass->student_name) {
            $this->syncService->syncStudentFutureDays($exceptionalClass->student_name, 90);
        }
    }
}
