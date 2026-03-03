<?php

use Illuminate\Support\Facades\Schedule;
use App\Jobs\CheckSlaBreachJob;
use App\Jobs\GenerateSessionsJob;
use App\Jobs\SendSessionRemindersJob;

/*
|--------------------------------------------------------------------------
| Console Routes / Scheduler
|--------------------------------------------------------------------------
*/

// SLA breach checker — runs every minute
Schedule::job(new CheckSlaBreachJob())->everyMinute()->withoutOverlapping();

// Session generator — runs daily at 2 AM
Schedule::job(new GenerateSessionsJob())->dailyAt('02:00')->withoutOverlapping();

// Reminder sender — runs every minute
Schedule::job(new SendSessionRemindersJob())->everyMinute()->withoutOverlapping();
