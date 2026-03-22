<?php

declare(strict_types=1);

namespace App\Services;

use App\Enums\TicketPriority;
use App\Enums\TicketStatus;
use App\Enums\UserAvailability;
use App\Models\Role;
use App\Models\Ticket;
use App\Models\TicketLog;
use App\Models\User;
use Illuminate\Support\Facades\DB;

class AdminService
{
    /**
     * List all supervisors with pagination.
     */
    public function listSupervisors(array $filters = [], int $perPage = 20)
    {
        $query = User::with('roles')
            ->role('supervisor', 'api')
            ->withCount(['tickets as open_ticket_count' => function ($q) {
                $q->whereIn('status', [TicketStatus::Open, TicketStatus::Pending]);
            }])
            ->latest();

        if (!empty($filters['availability'])) {
            $query->where('availability', $filters['availability']);
        }

        if (!empty($filters['search'])) {
            $search = $filters['search'];
            $query->where(function ($q) use ($search) {
                $q->where('name', 'ilike', "%{$search}%")
                  ->orWhere('email', 'ilike', "%{$search}%")
                  ->orWhere('phone', 'ilike', "%{$search}%");
            });
        }

        return $query->paginate($perPage);
    }

    /**
     * Create a new supervisor user.
     */
    public function createSupervisor(array $data): User
    {
        $user = User::create([
            'name'             => $data['name'],
            'email'            => $data['email'],
            'phone'            => $data['phone'] ?? null,
            'password'         => $data['password'],
            'max_open_tickets' => $data['max_open_tickets'] ?? 10,
            'availability'     => UserAvailability::Unavailable,
        ]);

        $user->assignRole(Role::findByName('supervisor', 'api') ?? 'supervisor');

        return $user->load('roles');
    }

    /**
     * Update supervisor details.
     */
    public function updateSupervisor(int $id, array $data): User
    {
        $user = User::findOrFail($id);

        $updateData = array_filter([
            'name'             => $data['name'] ?? null,
            'email'            => $data['email'] ?? null,
            'phone'            => $data['phone'] ?? null,
            'max_open_tickets' => $data['max_open_tickets'] ?? null,
        ], fn ($v) => $v !== null);

        if (!empty($data['password'])) {
            $updateData['password'] = $data['password'];
        }

        $user->update($updateData);

        return $user->refresh()->load('roles');
    }

    /**
     * Soft-delete a supervisor.
     */
    public function deleteSupervisor(int $id): void
    {
        $user = User::findOrFail($id);
        $user->delete();
    }

    /**
     * Get comprehensive analytics dashboard data.
     */
    public function analytics(array $params = []): array
    {
        $from = isset($params['from']) ? \Carbon\Carbon::parse($params['from']) : now()->subDays(30);
        $to   = isset($params['to']) ? \Carbon\Carbon::parse($params['to']) : now();

        return [
            'overview' => $this->getOverview($from, $to),
            'tickets_by_status' => $this->getTicketsByStatus(),
            'tickets_by_priority' => $this->getTicketsByPriority(),
            'daily_volume' => $this->getDailyVolume($from, $to),
            'supervisor_performance' => $this->getSupervisorPerformance($from, $to),
            'sla_compliance' => $this->getSlaCompliance($from, $to),
        ];
    }

    /**
     * Get audit trail with filters.
     */
    public function auditLog(array $filters = [], int $perPage = 50)
    {
        $query = TicketLog::with(['ticket:id,ticket_number', 'user:id,name'])
            ->orderBy('created_at', 'desc');

        if (!empty($filters['ticket_id'])) {
            $query->where('ticket_id', $filters['ticket_id']);
        }
        if (!empty($filters['user_id'])) {
            $query->where('user_id', $filters['user_id']);
        }
        if (!empty($filters['action'])) {
            $query->where('action', $filters['action']);
        }
        if (!empty($filters['from'])) {
            $query->where('created_at', '>=', $filters['from']);
        }
        if (!empty($filters['to'])) {
            $query->where('created_at', '<=', $filters['to']);
        }

        return $query->paginate($perPage);
    }

    // ── Private Analytics Helpers ─────────────────────────

    private function getOverview($from, $to): array
    {
        return [
            // Academy Stats
            'total_students'     => \App\Models\Student::count(),
            'active_students'    => \App\Models\Student::count(),
            'total_teachers'     => \App\Models\User::role(['teacher', 'api'])->count(),
            'total_schedules'    => \App\Models\Schedule::count(),
            'active_schedules'   => \App\Models\Schedule::count(),
            
            // Sessions Stats
            'total_sessions'     => \App\Models\ClassSession::whereBetween('session_date', [$from, $to])->count(),
            'completed_sessions' => \App\Models\ClassSession::whereBetween('session_date', [$from, $to])->where('status', 'completed')->count(),
            'cancelled_sessions' => \App\Models\ClassSession::whereBetween('session_date', [$from, $to])->where('status', 'cancelled')->count(),
            
            // Reminders Stats
            'pending_reminders'  => \App\Models\Reminder::whereBetween('created_at', [$from, $to])->where('status', 'pending')->count(),
            'sent_reminders'     => \App\Models\Reminder::whereBetween('created_at', [$from, $to])->where('status', 'sent')->count(),

            // Ticket & Supervisor Analytics
            'total_tickets'    => Ticket::whereBetween('created_at', [$from, $to])->count(),
            'resolved_tickets' => Ticket::whereBetween('created_at', [$from, $to])
                                       ->where('status', TicketStatus::Resolved)->count(),
            'open_tickets'     => Ticket::where('status', TicketStatus::Open)->count(),
            'sla_breached'     => Ticket::whereBetween('created_at', [$from, $to])
                                       ->where('sla_breached', true)->count(),
            'active_supervisors' => User::role(['supervisor', 'senior_supervisor'])
                                       ->where('availability', UserAvailability::Available)->count(),
            'avg_first_response_minutes' => round(
                (float) Ticket::whereBetween('created_at', [$from, $to])
                    ->whereNotNull('first_response_at')
                    ->selectRaw('AVG(EXTRACT(EPOCH FROM (first_response_at - created_at)) / 60) as avg_min')
                    ->value('avg_min') ?? 0,
                1
            ),
            'avg_resolution_minutes' => round(
                (float) Ticket::whereBetween('created_at', [$from, $to])
                    ->whereNotNull('resolved_at')
                    ->selectRaw('AVG(EXTRACT(EPOCH FROM (resolved_at - created_at)) / 60) as avg_min')
                    ->value('avg_min') ?? 0,
                1
            ),
        ];
    }

    private function getTicketsByStatus(): array
    {
        return Ticket::select('status', DB::raw('COUNT(*) as count'))
            ->groupBy('status')
            ->pluck('count', 'status')
            ->toArray();
    }

    private function getTicketsByPriority(): array
    {
        return Ticket::select('priority', DB::raw('COUNT(*) as count'))
            ->groupBy('priority')
            ->pluck('count', 'priority')
            ->toArray();
    }

    private function getDailyVolume($from, $to): array
    {
        return Ticket::whereBetween('created_at', [$from, $to])
            ->select(DB::raw("DATE(created_at) as date"), DB::raw('COUNT(*) as count'))
            ->groupBy('date')
            ->orderBy('date')
            ->pluck('count', 'date')
            ->toArray();
    }

    private function getSupervisorPerformance($from, $to): array
    {
        return User::role(['supervisor', 'senior_supervisor'])
            ->withCount([
                'tickets as total_tickets' => fn ($q) => $q->whereBetween('created_at', [$from, $to]),
                'tickets as resolved_tickets' => fn ($q) => $q->whereBetween('created_at', [$from, $to])
                    ->where('status', TicketStatus::Resolved),
                'tickets as open_tickets' => fn ($q) => $q->whereIn('status', [TicketStatus::Open, TicketStatus::Pending]),
            ])
            ->get()
            ->map(fn (User $u) => [
                'id'               => $u->id,
                'name'             => $u->name,
                'availability'     => $u->availability,
                'total_tickets'    => $u->total_tickets,
                'resolved_tickets' => $u->resolved_tickets,
                'open_tickets'     => $u->open_tickets,
            ])
            ->toArray();
    }

    private function getSlaCompliance($from, $to): array
    {
        $total = Ticket::whereBetween('created_at', [$from, $to])->count();
        $breached = Ticket::whereBetween('created_at', [$from, $to])->where('sla_breached', true)->count();

        return [
            'total'          => $total,
            'breached'       => $breached,
            'compliant'      => $total - $breached,
            'compliance_pct' => $total > 0 ? round((($total - $breached) / $total) * 100, 1) : 100,
        ];
    }
}
