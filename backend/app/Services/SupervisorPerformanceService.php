<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\User;
use App\Models\Ticket;
use App\Models\ClassSession;
use Illuminate\Support\Facades\DB;
use Carbon\Carbon;

class SupervisorPerformanceService
{
    /**
     * Get aggregated metrics for all supervisors within a date range.
     */
    public function getAggregatedStats(?string $from = null, ?string $to = null)
    {
        $startDate = $from ? Carbon::parse($from)->startOfDay() : Carbon::now()->subDays(30)->startOfDay();
        $endDate = $to ? Carbon::parse($to)->endOfDay() : Carbon::now()->endOfDay();

        $supervisors = User::role('supervisor')
            ->get()
            ->map(function ($supervisor) use ($startDate, $endDate) {
                return $this->calculateSupervisorMetrics($supervisor->id, $startDate, $endDate);
            });

        return $supervisors;
    }

    /**
     * Get detailed metrics for a single supervisor.
     */
    public function getSupervisorDetails(int $supervisorId, ?string $from = null, ?string $to = null)
    {
        $startDate = $from ? Carbon::parse($from)->startOfDay() : Carbon::now()->subDays(30)->startOfDay();
        $endDate = $to ? Carbon::parse($to)->endOfDay() : Carbon::now()->endOfDay();

        $metrics = $this->calculateSupervisorMetrics($supervisorId, $startDate, $endDate);

        // Fetch detailed historical records for drill-down views
        $tickets = Ticket::where('assigned_to', $supervisorId)
            ->whereBetween('created_at', [$startDate, $endDate])
            ->get();
            
        $sessions = ClassSession::where('supervisor_id', $supervisorId)
            ->whereBetween('session_date', [$startDate->toDateString(), $endDate->toDateString()])
            ->get();

        return [
            'metrics' => $metrics,
            'recent_tickets' => $tickets->take(20),
            'recent_sessions' => $sessions->take(20),
        ];
    }

    /**
     * Core calculation logic for a supervisor.
     */
    private function calculateSupervisorMetrics(int $supervisorId, Carbon $startDate, Carbon $endDate)
    {
        $supervisor = User::find($supervisorId);

        // -- TICKET METRICS --
        $ticketStats = Ticket::where('assigned_to', $supervisorId)
            ->whereBetween('created_at', [$startDate, $endDate])
            ->selectRaw('
                COUNT(id) as total_tickets,
                SUM(CASE WHEN sla_breached = 1 THEN 1 ELSE 0 END) as breached_tickets,
                AVG(TIMESTAMPDIFF(MINUTE, created_at, first_response_at)) as avg_first_response_minutes,
                AVG(TIMESTAMPDIFF(MINUTE, created_at, resolved_at)) as avg_resolution_minutes
            ')
            ->first();

        // -- CLASS SESSION METRICS --
        // To accurately get turnaround time, we check how quickly they update the session after end_time.
        // For simplicity, we fallback to session_date if end_time isn't fully parsable without date.
        // In our schema: session_date (date), start_time (string), end_time (string), updated_at (timestamp)
        // We'll calculate class action delay via PHP for accuracy due to time formats.
        $sessions = ClassSession::where('supervisor_id', $supervisorId)
            ->whereBetween('session_date', [$startDate->toDateString(), $endDate->toDateString()])
            ->get();

        $totalSessions = $sessions->count();
        $handledSessions = $sessions->whereIn('status', ['completed', 'cancelled', 'rescheduled'])->count();
        $classCompletionRate = $totalSessions > 0 ? ($handledSessions / $totalSessions) * 100 : 0;

        $totalActionDelayMinutes = 0;
        $actionableCount = 0;

        foreach ($sessions as $session) {
            if (in_array($session->status, ['completed', 'cancelled', 'rescheduled'])) {
                $endDateTimeStr = $session->session_date->format('Y-m-d') . ' ' . $session->end_time;
                try {
                    $endDateTime = Carbon::parse($endDateTimeStr);
                    // Avoid negative delay if they updated it before it ended (e.g., cancelled early)
                    $delay = max(0, $endDateTime->diffInMinutes($session->updated_at, false)); 
                    $totalActionDelayMinutes += $delay;
                    $actionableCount++;
                } catch (\Exception $e) {
                    continue; // Skip if parse fails
                }
            }
        }

        $avgClassActionDelay = $actionableCount > 0 ? ($totalActionDelayMinutes / $actionableCount) : null;

        // -- OVERALL SCORE CALCULATION --
        $frt = $ticketStats->avg_first_response_minutes ?? 0;
        $frtScore = 0;
        if ($frt > 0) {
            $frtScore = $frt <= 15 ? 50 : max(0, 50 - (($frt - 15) * 0.5)); // Drop score as it gets longer
        } elseif ($frt === 0 && $ticketStats->total_tickets > 0 && $ticketStats->avg_first_response_minutes !== null) {
            $frtScore = 50; // Responded instantly
        } else {
             $frtScore = 50; // default if no tickets
        }

        $classScore = 0;
        if ($actionableCount > 0) {
            // Target: within 60 minutes
            $classScore = $avgClassActionDelay <= 60 ? 50 : max(0, 50 - (($avgClassActionDelay - 60) * 0.2));
        } else {
            $classScore = 50;
        }

        // Adjust class score by handling completion rate
        $classScore = $classScore * ($classCompletionRate / 100);

        $overallScore = min(100, max(0, $frtScore + $classScore));

        return [
            'supervisor_id' => $supervisor->id,
            'name' => $supervisor->name,
            'metrics' => [
                'tickets_handled' => (int) $ticketStats->total_tickets,
                'avg_first_response_minutes' => $ticketStats->avg_first_response_minutes ? round((float) $ticketStats->avg_first_response_minutes) : null,
                'avg_resolution_minutes' => $ticketStats->avg_resolution_minutes ? round((float) $ticketStats->avg_resolution_minutes) : null,
                'sla_breach_rate' => $ticketStats->total_tickets > 0 ? round(($ticketStats->breached_tickets / $ticketStats->total_tickets) * 100) : 0,
                'classes_assigned' => $totalSessions,
                'classes_handled' => $handledSessions,
                'class_completion_rate' => round($classCompletionRate, 2),
                'avg_class_action_delay_minutes' => $avgClassActionDelay !== null ? round((float) $avgClassActionDelay) : null,
                'overall_score' => round($overallScore)
            ]
        ];
    }
}
