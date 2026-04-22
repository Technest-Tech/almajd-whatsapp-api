<?php

use Illuminate\Support\Facades\Schedule;

// Run auto-scheduler every 5 minutes to create reminder rows for today's sessions
Schedule::command('reminders:auto-schedule')->everyFiveMinutes();

// Rebalance sessions assigned to inactive supervisors every 15 minutes
Schedule::command('sessions:rebalance')->everyFifteenMinutes()->withoutOverlapping();

// Process and send pending reminders every minute
Schedule::job(new \App\Jobs\SendSessionRemindersJob())->everyMinute();

// Daily: generate sessions for all active students if running low (smart — skips if already covered)
Schedule::command('sessions:generate --months=3')->daily()->at('02:00');

// Weekly top-up: ensure we always have 3 months in advance (force on Sundays)
Schedule::command('sessions:generate --months=3 --force')->weeklyOn(0, '03:00');

// Nightly Legacy Calendar Bridge: Generate sessions for legacy rules exactly 7 days out
Schedule::command('calendar:sync-legacy 7')->dailyAt('00:00');
