<?php

namespace App\Providers;

use App\Models\CalendarTeacherTimetable;
use App\Models\CalendarExceptionalClass;
use App\Models\CalendarStudentStop;
use App\Observers\CalendarTeacherTimetableObserver;
use App\Observers\CalendarExceptionalClassObserver;
use App\Observers\CalendarStudentStopObserver;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        CalendarTeacherTimetable::observe(CalendarTeacherTimetableObserver::class);
        CalendarExceptionalClass::observe(CalendarExceptionalClassObserver::class);
        CalendarStudentStop::observe(CalendarStudentStopObserver::class);
    }
}
