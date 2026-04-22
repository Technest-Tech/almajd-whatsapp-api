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
     * Assign supervisor_id for sessions that have no supervisor yet, based on
     * who is on shift at the session's start time. All supervisors whose shift
     * covers the session time can see it via the shift-based inbox query; we
     * still record a primary supervisor_id for reporting/legacy purposes.
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

        DB::transaction(function () use ($sortedSessions): void {
            foreach ($sortedSessions as $session) {
                $sessionTime = Carbon::parse(
                    ($session->session_date instanceof Carbon
                        ? $session->session_date->format('Y-m-d')
                        : (string) $session->session_date)
                    . ' ' . $session->start_time
                );

                $supervisors = $this->shiftService->supervisorsOnShiftAt($sessionTime);

                if ($supervisors->isEmpty()) {
                    // No one on shift at this session's time — leave unassigned for admin.
                    continue;
                }

                // Check overflow alarm: warn if primary supervisor is over cap (non-blocking).
                $primary = $supervisors->first();
                $currentLoad = ClassSession::where('supervisor_id', $primary->id)
                    ->whereIn('status', self::LOAD_STATUSES)
                    ->count();

                $cap = $primary->max_open_tickets ?? 20;
                if ($currentLoad >= $cap) {
                    // Try next on-shift supervisor under cap
                    $primary = $supervisors->first(function (User $s) use ($cap): bool {
                        $load = ClassSession::where('supervisor_id', $s->id)
                            ->whereIn('status', self::LOAD_STATUSES)
                            ->count();
                        return $load < $cap;
                    }) ?? $supervisors->first(); // still assign even if all over cap
                }

                $session->update(['supervisor_id' => $primary->id]);
                $this->assignTicketsForSession($session, $primary->id);
            }
        });
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
