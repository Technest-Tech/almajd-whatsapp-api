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
        // Only sync if the exception is happening within the next 7 days buffer
        $date = Carbon::parse($exceptionalClass->date);
        if ($date->between(Carbon::today(), Carbon::today()->addDays(7))) {
            $this->syncService->syncDate($date);
        }
    }

    public function updated(CalendarExceptionalClass $exceptionalClass): void
    {
        $date = Carbon::parse($exceptionalClass->date);
        if ($date->between(Carbon::today(), Carbon::today()->addDays(7))) {
            $this->syncService->syncDate($date);
        }
    }
}
