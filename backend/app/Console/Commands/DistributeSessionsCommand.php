<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Models\User;
use App\Services\SessionLoadBalancerService;
use Carbon\Carbon;
use Illuminate\Console\Command;

class DistributeSessionsCommand extends Command
{
    protected $signature = 'sessions:distribute
        {--from= : Start date (Y-m-d). Defaults to today.}
        {--to= : End date (Y-m-d). Defaults to --from plus --days.}
        {--days=60 : Days ahead to cover when --to is omitted.}';

    protected $description = 'Re-balance active sessions evenly across the supervisors on each shift for a date range.';

    public function handle(SessionLoadBalancerService $balancer): int
    {
        $from = $this->option('from')
            ? Carbon::parse($this->option('from'))->startOfDay()
            : Carbon::today();

        $to = $this->option('to')
            ? Carbon::parse($this->option('to'))->startOfDay()
            : (clone $from)->addDays((int) $this->option('days'));

        $this->info("Redistributing active sessions {$from->toDateString()} → {$to->toDateString()} ...");

        $result = $balancer->redistributeRange($from, $to);

        $this->info("Reassigned: {$result['reassigned']}   Unassigned (no one on shift): {$result['unassigned']}");

        if (!empty($result['per_supervisor'])) {
            arsort($result['per_supervisor']);
            $this->line('Per supervisor:');
            foreach ($result['per_supervisor'] as $id => $count) {
                $name = User::find($id)?->name ?? '?';
                $this->line("  [{$id}] {$name}: {$count}");
            }
        }

        return self::SUCCESS;
    }
}
