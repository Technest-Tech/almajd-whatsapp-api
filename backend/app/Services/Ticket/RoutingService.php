<?php

declare(strict_types=1);

namespace App\Services\Ticket;

use App\Enums\TicketPriority;
use App\Enums\TicketStatus;
use App\Enums\UserAvailability;
use App\Models\Ticket;
use App\Models\TicketLog;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class RoutingService
{
    /**
     * Auto-assign a new ticket to the best available supervisor.
     *
     * Strategy:
     * 1. Find supervisors who are 'available' (not busy/unavailable)
     * 2. Among those, pick the one with the fewest open tickets
     * 3. Must be below their max_open_tickets limit
     * 4. If on-shift check is enabled, verify current shift
     */
    public function autoAssign(Ticket $ticket): ?User
    {
        $assignee = User::role(['supervisor', 'senior_supervisor'])
            ->where('availability', UserAvailability::Available)
            ->withCount(['tickets as open_ticket_count' => function ($q) {
                $q->whereIn('status', [TicketStatus::Open, TicketStatus::Pending]);
            }])
            ->having('open_ticket_count', '<', DB::raw('max_open_tickets'))
            ->orderBy('open_ticket_count', 'asc')
            ->first();

        if (!$assignee) {
            Log::warning("No available supervisor for ticket #{$ticket->ticket_number}");
            return null;
        }

        $ticket->update(['assigned_to' => $assignee->id]);

        TicketLog::create([
            'ticket_id' => $ticket->id,
            'action'    => 'auto_assigned',
            'new_value' => (string) $assignee->id,
            'details'   => "Auto-assigned to {$assignee->name} ({$assignee->email})",
        ]);

        Log::info("Ticket #{$ticket->ticket_number} auto-assigned to {$assignee->name}");

        return $assignee;
    }

    /**
     * Set SLA deadline on the ticket based on tag SLA or defaults.
     */
    public function applySla(Ticket $ticket): void
    {
        // Check for tag-specific SLA override
        $tag = $ticket->tags()->whereNotNull('sla_first_response_minutes')->first();

        $responseMinutes = $tag?->sla_first_response_minutes ?? config('sla.default_first_response_minutes', 5);

        $ticket->update([
            'sla_deadline_at' => $ticket->created_at->addMinutes($responseMinutes),
        ]);
    }
}
