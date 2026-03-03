<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Enums\TicketStatus;
use App\Http\Controllers\Controller;
use App\Services\ApiResponseService;
use App\Services\Ticket\TicketService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class TicketController extends Controller
{
    public function __construct(
        private readonly TicketService $ticketService,
        private readonly ApiResponseService $response,
    ) {}

    /**
     * GET /api/tickets
     */
    public function index(Request $request): JsonResponse
    {
        $paginator = $this->ticketService->list(
            filters: $request->only(['status', 'priority', 'assigned_to', 'sla_breached', 'search', 'tag_id']),
            perPage: (int) $request->input('per_page', 20),
        );

        return $this->response->paginated($paginator, 'Tickets retrieved');
    }

    /**
     * GET /api/tickets/stats
     */
    public function stats(Request $request): JsonResponse
    {
        $userId = $request->query('user_id') ? (int) $request->query('user_id') : null;

        return $this->response->success(
            $this->ticketService->stats($userId),
            'Stats retrieved'
        );
    }

    /**
     * GET /api/tickets/{ticket}
     */
    public function show(int $ticket): JsonResponse
    {
        $ticketData = $this->ticketService->show($ticket);

        return $this->response->success($ticketData, 'Ticket details');
    }

    /**
     * POST /api/tickets/{ticket}/reply
     */
    public function reply(Request $request, int $ticket): JsonResponse
    {
        $request->validate([
            'content'   => 'required|string|max:4096',
            'media_url' => 'nullable|url|max:500',
        ]);

        $ticketModel = \App\Models\Ticket::findOrFail($ticket);

        $message = $this->ticketService->reply(
            ticket: $ticketModel,
            userId: $request->user()->id,
            content: $request->input('content'),
            mediaUrl: $request->input('media_url'),
        );

        return $this->response->success($message, 'Reply sent', code: 201);
    }

    /**
     * PUT /api/tickets/{ticket}/assign
     */
    public function assign(Request $request, int $ticket): JsonResponse
    {
        $request->validate(['user_id' => 'required|exists:users,id']);

        $ticketModel = \App\Models\Ticket::findOrFail($ticket);

        $updated = $this->ticketService->assign(
            ticket: $ticketModel,
            assigneeId: (int) $request->input('user_id'),
            assigner: $request->user()->id,
        );

        return $this->response->success($updated, 'Ticket assigned');
    }

    /**
     * PUT /api/tickets/{ticket}/status
     */
    public function updateStatus(Request $request, int $ticket): JsonResponse
    {
        $request->validate([
            'status' => 'required|in:open,pending,resolved,closed',
        ]);

        $ticketModel = \App\Models\Ticket::findOrFail($ticket);

        $updated = $this->ticketService->updateStatus(
            ticket: $ticketModel,
            status: TicketStatus::from($request->input('status')),
            userId: $request->user()->id,
        );

        return $this->response->success($updated, 'Status updated');
    }

    /**
     * PUT /api/tickets/{ticket}/escalate
     */
    public function escalate(Request $request, int $ticket): JsonResponse
    {
        $request->validate(['reason' => 'nullable|string|max:500']);

        $ticketModel = \App\Models\Ticket::findOrFail($ticket);

        $updated = $this->ticketService->escalate(
            ticket: $ticketModel,
            userId: $request->user()->id,
            reason: $request->input('reason'),
        );

        return $this->response->success($updated, 'Ticket escalated');
    }

    /**
     * POST /api/tickets/{ticket}/note
     */
    public function addNote(Request $request, int $ticket): JsonResponse
    {
        $request->validate(['content' => 'required|string|max:2000']);

        $ticketModel = \App\Models\Ticket::findOrFail($ticket);

        $note = $this->ticketService->addNote(
            ticket: $ticketModel,
            userId: $request->user()->id,
            content: $request->input('content'),
        );

        return $this->response->success($note, 'Note added', code: 201);
    }
}
