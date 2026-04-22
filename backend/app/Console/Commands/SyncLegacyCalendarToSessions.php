<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Services\LegacyCalendarSyncService;

class SyncLegacyCalendarToSessions extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'calendar:sync-legacy {days=7 : Number of days to look ahead}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Reads the legacy visual calendar and generates class_sessions for the next X days.';

    /**
     * Execute the console command.
     */
    public function handle(LegacyCalendarSyncService $syncService): int
    {
        $days = (int) $this->argument('days');
        
        $this->info("Starting legacy calendar sync for the next $days days...");
        
        $syncService->syncFutureDays($days);
        
        $this->info('Sync completed successfully.');
        
        return Command::SUCCESS;
    }
}
