<?php

use Illuminate\Support\Facades\Schedule;

// Run auto-scheduler every 5 minutes to create reminder rows for today's sessions
Schedule::command('reminders:auto-schedule')->everyFiveMinutes();

// Process and send pending reminders every minute
Schedule::job(new \App\Jobs\SendSessionRemindersJob())->everyMinute();
