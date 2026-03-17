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
            filters: $request->only(['status', 'priority', 'assigned_to', 'sla_breached', 'search', 'tag_id', 'type']),
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
            'content'             => 'required_without:media_url|nullable|string|max:4096',
            'media_url'           => 'nullable|url|max:500',
            'reply_to_message_id' => 'nullable|string|max:255',
        ]);

        $ticketModel = \App\Models\Ticket::findOrFail($ticket);

        $message = $this->ticketService->reply(
            ticket: $ticketModel,
            userId: $request->user()->id,
            content: $request->input('content'),
            mediaUrl: $request->input('media_url'),
            replyToMessageId: $request->input('reply_to_message_id'),
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

    /**
     * POST /api/tickets/{ticket}/send-template
     * Send an approved WhatsApp template to a new / out-of-session contact.
     */
    public function sendTemplate(Request $request, int $ticket): JsonResponse
    {
        $data = $request->validate([
            'template_id' => 'required|exists:whatsapp_templates,id',
            'variables'   => 'nullable|array',
            'variables.*' => 'nullable|string|max:512',
        ]);

        $ticketModel = \App\Models\Ticket::findOrFail($ticket);

        $message = $this->ticketService->replyWithTemplate(
            ticket:     $ticketModel,
            userId:     $request->user()->id,
            templateId: (int) $data['template_id'],
            variables:  $data['variables'] ?? [],
        );

        return $this->response->success($message, 'Template sent', code: 201);
    }

    /**
     * POST /api/tickets/create-for-student
     * Create (or find) a ticket for a student so we can start a chat.
     */
    public function createForStudent(Request $request): JsonResponse
    {
        $data = $request->validate([
            'student_id' => 'required|exists:students,id',
        ]);

        $student = \App\Models\Student::findOrFail($data['student_id']);

        $phone = $student->whatsapp_number !== null && $student->whatsapp_number !== ''
            ? trim((string) $student->whatsapp_number)
            : '';
        if ($phone === '') {
            return $this->response->error('Student has no WhatsApp number', code: 422);
        }

        // Resolve or create Guardian
        $guardian = $student->guardian;
        if (!$guardian) {
            $guardian = \App\Models\Guardian::where('phone', $phone)->first();
            if (!$guardian) {
                $guardian = \App\Models\Guardian::create([
                    'name'  => $student->name,
                    'phone' => $phone,
                ]);
            }
        }

        // Update guardian name if still Unknown Contact
        if ($guardian->name === 'Unknown Contact') {
            $guardian->update(['name' => $student->name]);
        }

        // Find existing open/pending ticket or create one
        $ticket = \App\Models\Ticket::where('guardian_id', $guardian->id)
            ->whereIn('status', [
                \App\Enums\TicketStatus::Open,
                \App\Enums\TicketStatus::Pending,
            ])
            ->latest()
            ->first();

        if (!$ticket) {
            $ticket = \App\Models\Ticket::create([
                'ticket_number' => \App\Models\Ticket::generateTicketNumber(),
                'guardian_id'   => $guardian->id,
                'student_id'    => $student->id,
                'status'        => \App\Enums\TicketStatus::Open,
                'priority'      => \App\Enums\TicketPriority::Normal,
                'channel'       => 'whatsapp',
                'subject'       => 'New conversation with ' . $student->name,
            ]);
        } elseif (!$ticket->student_id) {
            $ticket->update(['student_id' => $student->id]);
        }

        $ticket->load(['guardian', 'student', 'assignedTo']);

        return $this->response->success($ticket, 'Ticket ready', code: 201);
    }

    /**
     * DELETE /api/tickets/{ticket}
     */
    public function destroy(int $ticket): JsonResponse
    {
        $ticketModel = \App\Models\Ticket::findOrFail($ticket);

        // Delete related messages first, then the ticket
        $ticketModel->messages()->delete();
        $ticketModel->delete();

        return $this->response->success(null, 'Ticket deleted');
    }

    /**
     * POST /api/tickets/{ticket}/read
     */
    public function markAsRead(int $ticket): JsonResponse
    {
        $ticketModel = \App\Models\Ticket::findOrFail($ticket);
        
        if ($ticketModel->unread_count > 0) {
            $ticketModel->unread_count = 0;
            $ticketModel->save();
        }

        return $this->response->success(null, 'Ticket marked as read');
    }

    /**
     * GET /api/tickets/{ticket}/messages?page=1&per_page=30
     * Paginated messages — newest first (reversed for chat display)
     */
    public function messages(Request $request, int $ticket): JsonResponse
    {
        $ticketModel = \App\Models\Ticket::findOrFail($ticket);
        $perPage = min((int) $request->input('per_page', 30), 100);

        $paginator = $ticketModel->messages()
            ->orderByDesc('id')
            ->paginate($perPage);

        // Reverse items so they're in chronological order for the client
        $paginator->setCollection($paginator->getCollection()->reverse()->values());

        return $this->response->paginated($paginator, 'Messages retrieved');
    }

    /**
     * GET /api/tickets/unread-count
     * Lightweight endpoint that returns total unread across all tickets
     */
    public function unreadCount(): JsonResponse
    {
        $count = \App\Models\Ticket::where('unread_count', '>', 0)->sum('unread_count');

        return $this->response->success(
            ['unread_count' => (int) $count],
            'Unread count retrieved'
        );
    }

    /**
     * POST /api/tickets/create-for-contact
     * Create (or find) a ticket for any phone number (e.g. a teacher).
     */
    public function createForContact(Request $request): JsonResponse
    {
        $data = $request->validate([
            'phone' => 'required|string|max:30',
            'name'  => 'nullable|string|max:255',
        ]);

        $phone = trim((string) $data['phone']);

        // Resolve or create Guardian
        $guardian = \App\Models\Guardian::where('phone', $phone)->first();
        if (!$guardian) {
            $guardian = \App\Models\Guardian::create([
                'name'  => $data['name'] ?? $phone,
                'phone' => $phone,
            ]);
        } elseif (!empty($data['name']) && $guardian->name === 'Unknown Contact') {
            $guardian->update(['name' => $data['name']]);
        }

        // Find existing open/pending ticket or create one
        $ticket = \App\Models\Ticket::where('guardian_id', $guardian->id)
            ->whereIn('status', [
                \App\Enums\TicketStatus::Open,
                \App\Enums\TicketStatus::Pending,
            ])
            ->latest()
            ->first();

        if (!$ticket) {
            $ticket = \App\Models\Ticket::create([
                'ticket_number' => \App\Models\Ticket::generateTicketNumber(),
                'guardian_id'   => $guardian->id,
                'status'        => \App\Enums\TicketStatus::Open,
                'priority'      => \App\Enums\TicketPriority::Normal,
                'channel'       => 'whatsapp',
                'subject'       => 'New conversation with ' . $guardian->name,
            ]);
        }

        $ticket->load(['guardian', 'student', 'assignedTo']);

        return $this->response->success($ticket, 'Ticket ready', code: 201);
    }
}
