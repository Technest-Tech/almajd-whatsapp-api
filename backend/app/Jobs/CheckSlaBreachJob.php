<?php

declare(strict_types=1);

namespace App\Jobs;

use App\Enums\TicketPriority;
use App\Enums\TicketStatus;
use App\Models\Ticket;
use App\Models\TicketLog;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

class CheckSlaBreachJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public function __construct()
    {
        $this->onQueue('default');
    }

    /**
     * Check all open/pending tickets for SLA breaches.
     * Runs every minute via scheduler.
     */
    public function handle(): void
    {
        $tickets = Ticket::whereIn('status', [TicketStatus::Open, TicketStatus::Pending])
            ->whereNotNull('sla_deadline_at')
            ->where('sla_breached', false)
            ->where('sla_deadline_at', '<=', now())
            ->get();

        foreach ($tickets as $ticket) {
            $ticket->update(['sla_breached' => true]);

            TicketLog::create([
                'ticket_id' => $ticket->id,
                'action'    => 'sla_breached',
                'details'   => "SLA deadline passed: {$ticket->sla_deadline_at}",
            ]);

            // Auto-escalate if enabled
            if (config('sla.auto_escalate')) {
                $ticket->update([
                    'escalation_level' => $ticket->escalation_level + 1,
                    'priority'         => TicketPriority::Urgent,
                ]);

                TicketLog::create([
                    'ticket_id' => $ticket->id,
                    'action'    => 'auto_escalated',
                    'details'   => 'Auto-escalated due to SLA breach',
                ]);
            }

            Log::warning("SLA breached for ticket #{$ticket->ticket_number}");

            // TODO: Send notification event to admin via Reverb
        }

        // Also check for tickets approaching SLA deadline (warning threshold)
        $warningPct = config('sla.warning_threshold_pct', 80) / 100;

        $warningTickets = Ticket::whereIn('status', [TicketStatus::Open, TicketStatus::Pending])
            ->whereNotNull('sla_deadline_at')
            ->where('sla_breached', false)
            ->get()
            ->filter(function ($ticket) use ($warningPct) {
                $totalMinutes = $ticket->created_at->diffInMinutes($ticket->sla_deadline_at);
                $elapsedMinutes = $ticket->created_at->diffInMinutes(now());
                return $totalMinutes > 0 && ($elapsedMinutes / $totalMinutes) >= $warningPct;
            });

        foreach ($warningTickets as $ticket) {
            Log::info("SLA warning: ticket #{$ticket->ticket_number} approaching deadline");
            // TODO: Send SLA warning notification
        }
    }
}
