<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Models\ClassSession;
use App\Models\ScheduleEntry;
use App\Models\Schedule;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

class WipeSchedulesCommand extends Command
{
    protected $signature = 'schedules:wipe-all {--force : Force operation without asking for confirmation}';

    protected $description = 'Dangerously wipe all schedules, schedule entries, and class sessions from the database for a clean slate reset.';

    public function handle(): int
    {
        if (!$this->option('force') && !$this->confirm('Are you sure you want to delete ALL schedules, entries, and class sessions? This is irreversible.')) {
            $this->info('Operation cancelled.');
            return Command::SUCCESS;
        }

        $this->warn('Beginning timetable wipe...');

        DB::transaction(function () {
            // Delete in foreign key order: child first, then parent
            $sessionsCount = ClassSession::query()->delete();
            $this->info("Deleted $sessionsCount class sessions.");

            $entriesCount = ScheduleEntry::query()->delete();
            $this->info("Deleted $entriesCount schedule entries.");

            $schedulesCount = Schedule::query()->delete();
            $this->info("Deleted $schedulesCount schedule templates.");
        });

        $this->info('✅ Clean slate achieved. All timetable-related data has been removed.');
        return Command::SUCCESS;
    }
}
