<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Models\ClassSession;
use App\Models\User;
use App\Services\SessionLoadBalancerService;
use Carbon\Carbon;
use Illuminate\Console\Command;

class RebalanceSessionsCommand extends Command
{
    protected $signature = 'sessions:rebalance {--inactive=30 : Minutes of inactivity before reassignment}';

    protected $description = 'Reassign sessions from inactive supervisors to available least-loaded supervisors.';

    public function handle(): int
    {
        $inactiveMinutes = (int) $this->option('inactive');
        $threshold = Carbon::now()->subMinutes($inactiveMinutes);

        // Best-effort pre-count for user-friendly logging.
        $inactiveSupervisorIds = User::whereHas('roles', function ($query) {
                $query->whereIn('name', ['supervisor', 'senior_supervisor'])
                    ->where('guard_name', 'api');
            })
            ->whereHas('classSessions', function ($q) use ($threshold) {
                $q->whereIn('status', ['scheduled', 'coming', 'pending'])
                    ->where('updated_at', '<', $threshold);
            })
            ->pluck('id');

        $sessionsToReassignCount = 0;
        if ($inactiveSupervisorIds->isNotEmpty()) {
            $sessionsToReassignCount = ClassSession::whereIn('supervisor_id', $inactiveSupervisorIds)
                ->whereIn('status', ['scheduled', 'coming', 'pending'])
                ->where('updated_at', '<', $threshold)
                ->count();
        }

        app(SessionLoadBalancerService::class)->rebalance($inactiveMinutes);

        $this->info("✅ Rebalanced sessions: {$sessionsToReassignCount} (inactive threshold: {$inactiveMinutes} min)");
        return Command::SUCCESS;
    }
}

