<?php

declare(strict_types=1);

namespace App\Services;

use App\Enums\UserAvailability;
use App\Models\ClassSession;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Database\Eloquent\Collection as EloquentCollection;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

class SessionLoadBalancerService
{
    /**
     * Session statuses considered for load/cap calculations and reassignment.
     */
    private const LOAD_STATUSES = ['scheduled', 'coming', 'rescheduled', 'pending', 'running'];

    /**
     * Session statuses considered when determining inactivity and rebalancing.
     */
    private const INACTIVE_STATUSES = ['scheduled', 'coming', 'pending'];

    /**
     * Assign supervisor_id for sessions that have no supervisor yet.
     *
     * Rules:
     * - Only assign to available supervisors.
     * - Always pick the supervisor with the lowest current load.
     * - Never exceed supervisor capacity (`max_open_tickets`).
     * - Process sessions ordered by date ASC then start_time ASC.
     */
    public function distribute(Collection $sessions): void
    {
        $unassigned = $sessions->filter(fn (ClassSession $s) => empty($s->supervisor_id));
        if ($unassigned->isEmpty()) {
            return;
        }

        $availableSupervisors = $this->getAvailableSupervisorsWithLoad();
        if ($availableSupervisors->isEmpty()) {
            return;
        }

        // Mutable in-memory load tracking so we don't need re-count after each assignment.
        $supervisorState = $availableSupervisors
            ->map(function (User $s): array {
                return [
                    'id' => $s->id,
                    'cap' => $s->max_open_tickets !== null ? (int) $s->max_open_tickets : 20,
                    'load' => isset($s->current_load) ? (int) $s->current_load : 0,
                ];
            })
            ->values()
            ->all();

        $sortedSessions = $unassigned->sortBy(function (ClassSession $s): string {
            $date = $s->session_date instanceof Carbon
                ? $s->session_date->format('Y-m-d')
                : (string) $s->session_date;

            return $date . ' ' . (string) $s->start_time;
        })->values();

        DB::transaction(function () use ($sortedSessions, &$supervisorState): void {
            foreach ($sortedSessions as $session) {
                $chosenIndex = null;
                $chosenLoad = PHP_INT_MAX;

                foreach ($supervisorState as $idx => $sup) {
                    if ($sup['load'] >= $sup['cap']) {
                        continue;
                    }

                    if ($sup['load'] < $chosenLoad) {
                        $chosenLoad = $sup['load'];
                        $chosenIndex = $idx;
                    }
                }

                if ($chosenIndex === null) {
                    // Everyone hit capacity; stop assigning further sessions.
                    break;
                }

                $supervisorId = $supervisorState[$chosenIndex]['id'];
                $session->update(['supervisor_id' => $supervisorId]);
                $supervisorState[$chosenIndex]['load']++;
            }
        });
    }

    /**
     * Assign all unassigned sessions (active statuses) to available supervisors.
     */
    public function distributeUnassignedGlobally(): void
    {
        $sessions = ClassSession::query()
            ->whereNull('supervisor_id')
            ->whereIn('status', self::LOAD_STATUSES)
            ->get();

        $this->distribute($sessions);
    }

    /**
     * Unassign this supervisor's active sessions and redistribute among available supervisors.
     */
    public function releaseSessionsFromSupervisor(int $supervisorUserId): void
    {
        $sessions = ClassSession::query()
            ->where('supervisor_id', $supervisorUserId)
            ->whereIn('status', self::LOAD_STATUSES)
            ->get();

        if ($sessions->isEmpty()) {
            return;
        }

        $sessionIds = $sessions->pluck('id')->all();

        DB::transaction(function () use ($sessionIds): void {
            ClassSession::whereIn('id', $sessionIds)
                ->update(['supervisor_id' => null]);
        });

        $freed = ClassSession::whereIn('id', $sessionIds)->get();
        $this->distribute($freed);
    }

    /**
     * Rebalance sessions from inactive supervisors, then distribute freed sessions.
     */
    public function rebalance(int $inactiveMinutes = 30): void
    {
        $threshold = Carbon::now()->subMinutes($inactiveMinutes);

        $inactiveSupervisorIds = User::whereHas('roles', function ($query) {
                $query->whereIn('name', ['supervisor', 'senior_supervisor'])
                    ->where('guard_name', 'api');
            })
            ->whereHas('classSessions', function ($q) use ($threshold) {
                $q->whereIn('status', self::INACTIVE_STATUSES)
                    ->where('updated_at', '<', $threshold);
            })
            ->pluck('id');

        if ($inactiveSupervisorIds->isEmpty()) {
            return;
        }

        $sessions = ClassSession::whereIn('supervisor_id', $inactiveSupervisorIds)
            ->whereIn('status', self::INACTIVE_STATUSES)
            ->where('updated_at', '<', $threshold)
            ->get();

        if ($sessions->isEmpty()) {
            return;
        }

        $sessionIds = $sessions->pluck('id')->all();

        DB::transaction(function () use ($sessionIds): void {
            ClassSession::whereIn('id', $sessionIds)
                ->update(['supervisor_id' => null]);
        });

        // Re-fetch to ensure supervisor_id is null on the instances we distribute.
        $freedSessions = ClassSession::whereIn('id', $sessionIds)->get();
        $this->distribute($freedSessions);
    }

    /**
     * Get available supervisors ordered by current load ascending.
     *
     * We use `withCount` over `User::classSessions` to avoid N+1 queries.
     *
     * @return EloquentCollection<int, User>
     */
    private function getAvailableSupervisorsWithLoad(): EloquentCollection
    {
        return User::whereHas('roles', function ($query) {
                $query->whereIn('name', ['supervisor', 'senior_supervisor'])
                    ->where('guard_name', 'api');
            })
            ->where('availability', UserAvailability::Available->value)
            ->withCount([
                'classSessions as current_load' => function ($q) {
                    $q->whereIn('status', self::LOAD_STATUSES);
                },
            ])
            ->orderBy('current_load', 'asc')
            ->get(['id', 'max_open_tickets', 'availability']);
    }
}

