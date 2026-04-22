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
            filters: $request->only(['status', 'priority', 'assigned_to', 'sla_breached', 'search', 'tag_id', 'type', 'unassigned', 'session_supervisor_id', 'today_sessions']),
            perPage: (int) $request->input('per_page', 20),
            viewer:  $request->user(),
        );

        if ($this->isSupervisorViewer($request->user())) {
            $paginator->getCollection()->each(fn ($ticket) => $this->redactTicketPhones($ticket));
        }

        return $this->response->paginated($paginator, 'Tickets retrieved');
    }

    /**
     * GET /api/tickets/stats
     */
    public function stats(Request $request): JsonResponse
    {
        $userId = $request->query('user_id') ? (int) $request->query('user_id') : null;

        return $this->response->success(
            $this->ticketService->stats($userId, viewer: $request->user()),
            'Stats retrieved'
        );
    }

    /**
     * GET /api/tickets/{ticket}
     */
    public function show(Request $request, int $ticket): JsonResponse
    {
        $ticketData = $this->ticketService->show($ticket);

        if ($this->isSupervisorViewer($request->user())) {
            $this->redactTicketPhones($ticketData);
        }

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
     * GET /api/tickets/{ticket}/messages?page=1&per_page=15
     * Paginated messages — newest first (reversed for chat display)
     */
    public function messages(Request $request, int $ticket): JsonResponse
    {
        $ticketModel = \App\Models\Ticket::findOrFail($ticket);
        $perPage = min((int) $request->input('per_page', 15), 100);

        $paginator = $ticketModel->messages()
            ->orderByDesc('id')
            ->paginate($perPage);

        // Reverse items so they're in chronological order for the client
        $paginator->setCollection($paginator->getCollection()->reverse()->values());

        if ($this->isSupervisorViewer($request->user())) {
            $paginator->getCollection()->each(fn ($msg) => $msg->makeHidden(['from_number', 'to_number']));
        }

        return $this->response->paginated($paginator, 'Messages retrieved');
    }

    /**
     * GET /api/tickets/unread-count
     * Lightweight endpoint that returns total unread for the authenticated user's scope
     */
    public function unreadCount(Request $request): JsonResponse
    {
        $user  = $request->user();
        $query = \App\Models\Ticket::where('unread_count', '>', 0);

        if ($this->isSupervisorViewer($user)) {
            $supervisorId = $user->id;
            $today        = now()->toDateString();

            $query->whereHas('guardian', function ($gq) use ($supervisorId, $today) {
                $gq->where(function ($inner) use ($supervisorId, $today) {
                    $inner->whereExists(function ($sub) use ($supervisorId, $today) {
                        $sub->selectRaw('1')
                            ->from('class_sessions as cs_s')
                            ->join('students as st', 'st.id', '=', 'cs_s.student_id')
                            ->whereColumn('st.whatsapp_number', 'guardians.phone')
                            ->whereDate('cs_s.session_date', $today)
                            ->whereNotIn('cs_s.status', ['cancelled', 'completed'])
                            ->whereExists(function ($sh) use ($supervisorId) {
                                $sh->selectRaw('1')
                                    ->from('shifts')
                                    ->where('shifts.user_id', $supervisorId)
                                    ->where('shifts.is_active', true)
                                    ->whereRaw('shifts.day_of_week = DAYOFWEEK(cs_s.session_date) - 1')
                                    ->whereRaw('shifts.start_time <= cs_s.start_time')
                                    ->whereRaw('shifts.end_time > cs_s.start_time');
                            });
                    })->orWhereExists(function ($sub) use ($supervisorId, $today) {
                        $sub->selectRaw('1')
                            ->from('class_sessions as cs_t')
                            ->join('teachers as t', 't.id', '=', 'cs_t.teacher_id')
                            ->whereColumn('t.whatsapp_number', 'guardians.phone')
                            ->whereDate('cs_t.session_date', $today)
                            ->whereNotIn('cs_t.status', ['cancelled', 'completed'])
                            ->whereExists(function ($sh) use ($supervisorId) {
                                $sh->selectRaw('1')
                                    ->from('shifts')
                                    ->where('shifts.user_id', $supervisorId)
                                    ->where('shifts.is_active', true)
                                    ->whereRaw('shifts.day_of_week = DAYOFWEEK(cs_t.session_date) - 1')
                                    ->whereRaw('shifts.start_time <= cs_t.start_time')
                                    ->whereRaw('shifts.end_time > cs_t.start_time');
                            });
                    });
                });
            });
        }

        $count = $query->sum('unread_count');

        return $this->response->success(
            ['unread_count' => (int) $count],
            'Unread count retrieved'
        );
    }

    /**
     * POST /api/tickets/{ticket}/claim
     * Soft-claim a ticket so others see "X is replying" for 2 minutes.
     * Refreshed automatically on each reply/upload; expires silently.
     */
    public function claim(Request $request, int $ticket): JsonResponse
    {
        $ticketModel = \App\Models\Ticket::findOrFail($ticket);

        $ticketModel->update([
            'handling_by'    => $request->user()->id,
            'handling_until' => now()->addMinutes(2),
        ]);

        return $this->response->success([
            'handling_by'    => $request->user()->id,
            'handling_until' => $ticketModel->handling_until,
        ], 'Ticket claimed');
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
        $providedName = isset($data['name']) ? trim((string) $data['name']) : null;
        if ($providedName !== null && $providedName === '') {
            $providedName = null;
        }

        // Resolve or create Guardian
        $guardian = \App\Models\Guardian::where('phone', $phone)->first();
        if (!$guardian) {
            $guardian = \App\Models\Guardian::create([
                'name'  => $providedName ?? $phone,
                'phone' => $phone,
            ]);
        } elseif ($providedName !== null) {
            // Replace placeholders so Inbox shows the correct name.
            if ($guardian->name === 'Unknown Contact' || $guardian->name === $phone) {
                $guardian->update(['name' => $providedName]);
            }
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

    private function isSupervisorViewer(\App\Models\User $user): bool
    {
        return $user->hasRole('supervisor', 'api')
            && !$user->hasAnyRole(['admin', 'senior_supervisor'], 'api');
    }

    private function redactTicketPhones(\App\Models\Ticket $ticket): void
    {
        if ($ticket->relationLoaded('guardian') && $ticket->guardian) {
            $ticket->guardian->makeHidden(['phone']);
        }
        if ($ticket->relationLoaded('student') && $ticket->student) {
            $ticket->student->makeHidden(['whatsapp_number']);
        }
        if ($ticket->relationLoaded('teacher') && $ticket->teacher) {
            $ticket->teacher->makeHidden(['whatsapp_number']);
        }
        if ($ticket->relationLoaded('messages')) {
            $ticket->messages->each(fn ($msg) => $msg->makeHidden(['from_number', 'to_number']));
        }
    }
}
