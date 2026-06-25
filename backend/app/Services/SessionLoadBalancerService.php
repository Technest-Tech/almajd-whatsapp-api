<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\ClassSession;
use App\Models\Guardian;
use App\Models\Student;
use App\Models\Teacher;
use App\Models\Ticket;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

class SessionLoadBalancerService
{
    /**
     * Session statuses considered active for assignment and routing.
     */
    private const LOAD_STATUSES = ['scheduled', 'coming', 'rescheduled', 'pending', 'running'];

    public function __construct(private readonly ShiftService $shiftService) {}

    /**
     * Assign supervisor_id for sessions that have no supervisor yet, spreading
     * each shift's lessons EVENLY across every supervisor on that shift.
     *
     * For each session we look up who is on shift at its start time and hand it
     * to the least-loaded of those supervisors (balanced round-robin, tie-broken
     * by user id). A per-day running tally — seeded from sessions already
     * assigned that day — keeps repeat/incremental runs balanced and naturally
     * handles overlapping shifts (a supervisor only receives sessions that fall
     * inside their own window).
     */
    public function distribute(Collection $sessions): void
    {
        $unassigned = $sessions->filter(fn (ClassSession $s) => empty($s->supervisor_id));
        if ($unassigned->isEmpty()) {
            return;
        }

        $sortedSessions = $unassigned->sortBy(function (ClassSession $s): string {
            $date = $s->session_date instanceof Carbon
                ? $s->session_date->format('Y-m-d')
                : (string) $s->session_date;

            return $date . ' ' . (string) $s->start_time;
        })->values();

        // $dayLoad[$date][$supervisorId] = number of sessions assigned to that
        // supervisor on that day so far (seeded lazily from the DB below).
        $dayLoad = [];

        DB::transaction(function () use ($sortedSessions, &$dayLoad): void {
            foreach ($sortedSessions as $session) {
                $date = $session->session_date instanceof Carbon
                    ? $session->session_date->format('Y-m-d')
                    : (string) $session->session_date;

                $sessionTime = Carbon::parse($date . ' ' . $session->start_time);
                $supervisors = $this->shiftService->supervisorsOnShiftAt($sessionTime);

                if ($supervisors->isEmpty()) {
                    // No one on shift at this session's time — leave for admin.
                    continue;
                }

                if (!isset($dayLoad[$date])) {
                    $dayLoad[$date] = [];
                }

                // Seed any supervisor not yet seen on this day from their
                // existing same-day assignments so the balance is fair.
                foreach ($supervisors as $sup) {
                    if (!array_key_exists($sup->id, $dayLoad[$date])) {
                        $dayLoad[$date][$sup->id] = ClassSession::whereDate('session_date', $date)
                            ->where('supervisor_id', $sup->id)
                            ->count();
                    }
                }

                // Pick the on-shift supervisor carrying the fewest sessions today
                // (deterministic tie-break by lowest user id).
                $chosen = null;
                $best   = null;
                foreach ($supervisors as $sup) {
                    $load = $dayLoad[$date][$sup->id];
                    if ($chosen === null
                        || $load < $best
                        || ($load === $best && $sup->id < $chosen->id)) {
                        $chosen = $sup;
                        $best   = $load;
                    }
                }

                $session->update(['supervisor_id' => $chosen->id]);
                $dayLoad[$date][$chosen->id]++;
                $this->assignTicketsForSession($session, $chosen->id);
            }
        });
    }

    /**
     * Re-balance every active session in a date range across the supervisors on
     * shift at each session's time. Existing assignments in the range are
     * cleared first, so the result is an even split rather than an incremental
     * top-up of whatever was assigned before.
     *
     * @return array{reassigned:int, unassigned:int, per_supervisor:array<int,int>}
     */
    public function redistributeRange(Carbon $from, Carbon $to): array
    {
        $sessions = ClassSession::query()
            ->whereBetween('session_date', [$from->toDateString(), $to->toDateString()])
            ->whereIn('status', self::LOAD_STATUSES)
            ->get();

        if ($sessions->isEmpty()) {
            return ['reassigned' => 0, 'unassigned' => 0, 'per_supervisor' => []];
        }

        $ids = $sessions->pluck('id');
        ClassSession::whereIn('id', $ids)->update(['supervisor_id' => null]);
        $sessions->each(fn (ClassSession $s) => $s->setAttribute('supervisor_id', null));

        $this->distribute($sessions);

        $per        = [];
        $unassigned = 0;
        foreach (ClassSession::whereIn('id', $ids)->get(['id', 'supervisor_id']) as $s) {
            if ($s->supervisor_id === null) {
                $unassigned++;
                continue;
            }
            $per[$s->supervisor_id] = ($per[$s->supervisor_id] ?? 0) + 1;
        }

        return [
            'reassigned'     => array_sum($per),
            'unassigned'     => $unassigned,
            'per_supervisor' => $per,
        ];
    }

    /**
     * Assign all unassigned active sessions globally.
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
     * With shift-based routing, going offline/unavailable does not forcibly
     * release sessions — visibility is derived from the shift schedule, not
     * availability flags. This method is kept for backward compatibility with
     * any callers but is now a no-op.
     */
    public function releaseSessionsFromSupervisor(int $supervisorUserId): void
    {
        // No-op: shift-based inbox query handles visibility without needing
        // to clear session_supervisor_id on tickets.
    }

    /**
     * Rebalancing is no longer needed: shift schedules are the capacity plan.
     * Kept as a no-op so existing cron/command references don't break.
     */
    public function rebalance(int $inactiveMinutes = 30): void
    {
        // No-op under shift-based assignment model.
    }

    /**
     * Route an inbound ticket to the on-shift supervisor(s).
     * Sets session_supervisor_id on the ticket to the primary on-shift supervisor
     * (for logging/legacy); actual inbox visibility is handled by the shift query.
     *
     * Returns the primary supervisor_id, or null if no one is on shift.
     */
    public function assignTicketToSessionSupervisor(Ticket $ticket, string $contactPhone): ?int
    {
        $today = Carbon::today()->toDateString();

        // Verify contact has a relevant session today
        $session = ClassSession::query()
            ->where('session_date', $today)
            ->whereIn('status', self::LOAD_STATUSES)
            ->where(function ($q) use ($contactPhone) {
                $q->whereHas('student', fn ($s) => $s->where('whatsapp_number', $contactPhone)
                    ->orWhere('whatsapp_number', ltrim($contactPhone, '+')))
                  ->orWhereHas('teacher', fn ($t) => $t->where('whatsapp_number', $contactPhone)
                      ->orWhere('whatsapp_number', ltrim($contactPhone, '+')));
            })
            ->orderByRaw("ABS(EXTRACT(EPOCH FROM (CONCAT(session_date, ' ', start_time)::timestamp - NOW())) / 60)")
            ->first();

        if (!$session) {
            return null;
        }

        // Find supervisors on shift now (with grace window)
        $onShift = $this->shiftService->supervisorsOnShiftNow(withGrace: true);

        if ($onShift->isEmpty()) {
            return null;
        }

        $primary = $onShift->first();
        $ticket->update(['session_supervisor_id' => $primary->id]);

        return $primary->id;
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Private Helpers
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * Set session_supervisor_id on all open/pending tickets for a session's
     * student and teacher, pointing to the given supervisor (for legacy/reports).
     */
    private function assignTicketsForSession(ClassSession $session, int $supervisorId): void
    {
        $phones = collect();

        $student = $session->student ?? Student::find($session->student_id);
        if ($student?->whatsapp_number) {
            $phones->push($student->whatsapp_number);
            $phones->push(ltrim($student->whatsapp_number, '+'));
            $phones->push('+' . ltrim($student->whatsapp_number, '+'));
        }

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

        $guardianIds = Guardian::whereIn('phone', $phones)->pluck('id');
        if ($guardianIds->isEmpty()) {
            return;
        }

        Ticket::whereIn('guardian_id', $guardianIds)
            ->whereNotIn('status', ['resolved', 'closed'])
            ->update(['session_supervisor_id' => $supervisorId]);
    }
}
