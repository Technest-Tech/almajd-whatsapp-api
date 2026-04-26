<?php

use Illuminate\Support\Facades\Schedule;

// ── Reminders ────────────────────────────────────────────────────────────────
// Run auto-scheduler every 5 minutes to create reminder rows for today's sessions
Schedule::command('reminders:auto-schedule')->everyFiveMinutes()->withoutOverlapping(10);

// Process and send pending reminders every minute
Schedule::job(new \App\Jobs\SendSessionRemindersJob())->everyMinute()->withoutOverlapping(5);

// Hourly: nudge teachers who haven't yet submitted their session report (max 2 nudges)
Schedule::job(new \App\Jobs\SendReportNudgeJob())->hourly()->withoutOverlapping();

// ── Session Generation ────────────────────────────────────────────────────────
// NOTE: Session generation is now ADMIN-TRIGGERED via the Calendar app buttons.
// The commands below have been intentionally removed to prevent uncontrolled
// data generation:
//   ❌ sessions:generate --months=3       (was: daily at 02:00)
//   ❌ sessions:generate --months=3 --force (was: weekly on Sunday at 03:00)
//   ❌ calendar:sync-legacy 7              (was: daily at 00:00)
//
// To generate sessions, use the "Generate Sessions" button in the Calendar admin page.
