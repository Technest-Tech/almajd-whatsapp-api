<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\ApiResponseService;
use App\Services\SupervisorPerformanceService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\StreamedResponse;
use App\Models\User;
use Carbon\Carbon;

class SupervisorPerformanceController extends Controller
{
    public function __construct(
        private readonly SupervisorPerformanceService $performanceService,
        private readonly ApiResponseService $response,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $stats = $this->performanceService->getAggregatedStats(
            $request->query('from'),
            $request->query('to')
        );

        return $this->response->success($stats, 'Aggregated metrics retrieved');
    }

    public function show(Request $request, int $id): JsonResponse
    {
        $details = $this->performanceService->getSupervisorDetails(
            $id,
            $request->query('from'),
            $request->query('to')
        );

        return $this->response->success($details, 'Supervisor details retrieved');
    }

    public function export(Request $request, int $id): StreamedResponse 
    {
        $supervisor = User::findOrFail($id);
        
        $from = $request->query('from');
        $to = $request->query('to');
        
        $details = $this->performanceService->getSupervisorDetails($id, $from, $to);
        
        $fileName = "supervisor_{$supervisor->name}_performance_" . Carbon::now()->format('Y-m-d_His') . ".csv";

        $headers = [
            "Content-type"        => "text/csv",
            "Content-Disposition" => "attachment; filename={$fileName}",
            "Pragma"              => "no-cache",
            "Cache-Control"       => "must-revalidate, post-check=0, pre-check=0",
            "Expires"             => "0"
        ];
        
        $columns = ['Type', 'ID/Title', 'Date/Created', 'Time/Response Time', 'Final Status'];

        $callback = function() use($details, $columns) {
            $file = fopen('php://output', 'w');
            
            // Add UTF-8 BOM for Excel compatibility with Arabic characters
            fprintf($file, chr(0xEF).chr(0xBB).chr(0xBF));
            
            fputcsv($file, ['Supervisor Performance Report']);
            fputcsv($file, []);
            
            fputcsv($file, ['METRICS SUMMARY']);
            $m = $details['metrics']['metrics'];
            fputcsv($file, ['Overall Score', $m['overall_score'] . '%']);
            fputcsv($file, ['Avg First Response (mins)', $m['avg_first_response_minutes']]);
            fputcsv($file, ['Avg Resolution (mins)', $m['avg_resolution_minutes']]);
            fputcsv($file, ['Classes Handled', $m['classes_handled'] . '/' . $m['classes_assigned']]);
            fputcsv($file, ['Avg Class Delay (mins)', $m['avg_class_action_delay_minutes']]);
            fputcsv($file, []);

            fputcsv($file, ['DETAILED LOGS']);
            fputcsv($file, $columns);

            $tickets = $details['recent_tickets'];
            foreach ($tickets as $ticket) {
                $frt = "N/A";
                if ($ticket->first_response_at) {
                    $frtMinutes = round($ticket->created_at->diffInMinutes($ticket->first_response_at));
                    $frt = "{$frtMinutes} mins";
                }
                
                fputcsv($file, [
                    'Ticket',
                    $ticket->ticket_number,
                    $ticket->created_at->format('Y-m-d H:i'),
                    $frt,
                    $ticket->status->value
                ]);
            }

            $sessions = $details['recent_sessions'];
            foreach ($sessions as $session) {
                $delay = "N/A";
                if (in_array($session->status, ['completed', 'cancelled', 'rescheduled'])) {
                    try {
                        $endDateTime = Carbon::parse($session->session_date->format('Y-m-d') . ' ' . $session->end_time);
                        $delayMins = round($endDateTime->diffInMinutes($session->updated_at, true));
                        $delay = "{$delayMins} mins delay";
                    } catch (\Exception $e) {}
                }
                
                fputcsv($file, [
                    'Class',
                    $session->title,
                    $session->session_date->format('Y-m-d'),
                    $delay,
                    $session->status
                ]);
            }

            fclose($file);
        };

        return response()->stream($callback, 200, $headers);
    }
}
