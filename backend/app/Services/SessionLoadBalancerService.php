<?php

declare(strict_types=1);

namespace App\Services;

use App\Enums\UserAvailability;
use App\Models\ClassSession;
use App\Models\Guardian;
use App\Models\Student;
use App\Models\Teacher;
use App\Models\Ticket;
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
     * Assign supervisor_id for sessions that have no supervisor yet,
     * then link the corresponding tickets to the same supervisor.
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
                    'id'   => $s->id,
                    'cap'  => $s->max_open_tickets !== null ? (int) $s->max_open_tickets : 20,
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
                $chosenLoad  = PHP_INT_MAX;

                foreach ($supervisorState as $idx => $sup) {
                    if ($sup['load'] >= $sup['cap']) {
                        continue;
                    }

                    if ($sup['load'] < $chosenLoad) {
                        $chosenLoad  = $sup['load'];
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

                // Also link the related tickets to this supervisor.
                $this->assignTicketsForSession($session, $supervisorId);
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
     * Unassign this supervisor's active sessions and redistribute among available supervisors,
     * and also release the related ticket scoping.
     */
    public function releaseSessionsFromSupervisor(int $supervisorUserId): void
    {
        $sessions = ClassSession::query()
            ->where('supervisor_id', $supervisorUserId)
            ->whereIn('status', self::LOAD_STATUSES)
            ->get();

        if ($sessions->isEmpty()) {
            // Still release any tickets scoped to this supervisor
            $this->releaseTicketsFromSupervisor($supervisorUserId);
            return;
        }

        $sessionIds = $sessions->pluck('id')->all();

        DB::transaction(function () use ($sessionIds, $supervisorUserId): void {
            ClassSession::whereIn('id', $sessionIds)
                ->update(['supervisor_id' => null]);

            // Release ticket scoping for sessions being freed
            $this->releaseTicketsFromSupervisor($supervisorUserId);
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

        DB::transaction(function () use ($sessionIds, $inactiveSupervisorIds): void {
            ClassSession::whereIn('id', $sessionIds)
                ->update(['supervisor_id' => null]);

            // Release ticket scoping for all inactive supervisors
            foreach ($inactiveSupervisorIds as $supId) {
                $this->releaseTicketsFromSupervisor($supId);
            }
        });

        // Re-fetch to ensure supervisor_id is null on the instances we distribute.
        $freedSessions = ClassSession::whereIn('id', $sessionIds)->get();
        $this->distribute($freedSessions);
    }

    /**
     * Assign the ticket for a given session's student/teacher to a supervisor.
     * Called when a new inbound message arrives from a session participant.
     *
     * Returns the supervisor_id that was assigned, or null if not found.
     */
    public function assignTicketToSessionSupervisor(Ticket $ticket, string $contactPhone): ?int
    {
        $today    = Carbon::today()->toDateString();
        $nowTime  = Carbon::now()->format('H:i:s');

        // Find the most relevant active session for this phone number today,
        // ordered by nearest start_time to now.
        $session = ClassSession::query()
            ->where('session_date', $today)
            ->whereIn('status', self::LOAD_STATUSES)
            ->whereNotNull('supervisor_id')
            ->where(function ($q) use ($contactPhone) {
                // Student match
                $q->whereHas('student', fn ($s) => $s->where('whatsapp_number', $contactPhone)
                    ->orWhere('whatsapp_number', ltrim($contactPhone, '+')))
                // Teacher match
                ->orWhereHas('teacher', fn ($t) => $t->where('whatsapp_number', $contactPhone)
                    ->orWhere('whatsapp_number', ltrim($contactPhone, '+')));
            })
            ->orderByRaw("ABS(TIMESTAMPDIFF(MINUTE, CONCAT(session_date, ' ', start_time), NOW()))")
            ->first();

        if (!$session || !$session->supervisor_id) {
            return null;
        }

        $ticket->update(['session_supervisor_id' => $session->supervisor_id]);

        return $session->supervisor_id;
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Private Helpers
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * Find all tickets whose contact (student/teacher) belongs to a given session
     * and set their session_supervisor_id.
     */
    private function assignTicketsForSession(ClassSession $session, int $supervisorId): void
    {
        $phones = collect();

        // Load student phone
        $student = $session->student ?? Student::find($session->student_id);
        if ($student?->whatsapp_number) {
            $phones->push($student->whatsapp_number);
            $phones->push(ltrim($student->whatsapp_number, '+'));
            $phones->push('+' . ltrim($student->whatsapp_number, '+'));
        }

        // Load teacher phone
        $teacher = $session->teacher ?? Teacher::find($session->teacher_id);
        if ($teacher?->whatsapp_number) {
            $phones->push($teacher->whatsapp_number);
            $phones->push(ltrim($teacher->whatsapp_number, '+'));
            $phones->push('+' . ltrim($teacher->whatsapp_number, '+'));
        }

        $phones = $phones->filter()->unique()->values();

        if ($phones->isEmpty()) {
            return;
        }

        // Find guardians whose phones match
        $guardianIds = Guardian::whereIn('phone', $phones)->pluck('id');

        if ($guardianIds->isEmpty()) {
            return;
        }

        // Assign open/pending tickets for these guardians to the supervisor
        Ticket::whereIn('guardian_id', $guardianIds)
            ->whereNotIn('status', ['resolved', 'closed'])
            ->update(['session_supervisor_id' => $supervisorId]);
    }

    /**
     * Set session_supervisor_id = null for all tickets owned by this supervisor.
     * Called when a supervisor goes offline or is rebalanced.
     */
    private function releaseTicketsFromSupervisor(int $supervisorUserId): void
    {
        Ticket::where('session_supervisor_id', $supervisorUserId)
            ->whereNotIn('status', ['resolved', 'closed'])
            ->update(['session_supervisor_id' => null]);
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
