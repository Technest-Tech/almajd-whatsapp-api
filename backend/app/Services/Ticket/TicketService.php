<?php

declare(strict_types=1);

namespace App\Services\Ticket;

use App\Enums\TicketPriority;
use App\Enums\TicketStatus;
use App\Enums\DeliveryStatus;
use App\Enums\MessageDirection;
use App\Enums\MessageType;
use App\Jobs\SendWhatsAppMessageJob;
use App\Models\Guardian;
use App\Models\Ticket;
use App\Models\TicketLog;
use App\Models\TicketNote;
use App\Models\User;
use App\Models\WhatsappMessage;
use App\Models\WhatsappTemplate;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class TicketService
{
    /**
     * List tickets with filters and pagination.
     *
     * Scoping rules:
     *  - admin / senior_supervisor  → see ALL tickets (including unassigned, session_supervisor_id=null)
     *  - supervisor                 → see only tickets where session_supervisor_id = their user ID
     *
     * When `unassigned=1` filter is passed, only show tickets with no session supervisor (admin only).
     */
    public function list(array $filters = [], int $perPage = 20, ?User $viewer = null): LengthAwarePaginator
    {
        $query = Ticket::with(['guardian', 'student', 'assignedTo', 'tags'])
            ->orderByDesc('last_message_at')
            ->orderByDesc('created_at');

        // ── Role-based scoping ──────────────────────────────────────────────
        if ($viewer && $viewer->hasRole('supervisor', 'api') && !$viewer->hasAnyRole(['admin', 'senior_supervisor'], 'api')) {
            // Regular supervisors: only see their scoped tickets
            $query->where('session_supervisor_id', $viewer->id);
        } elseif ($viewer && isset($filters['unassigned']) && (bool) $filters['unassigned']) {
            // Admins requesting the unassigned (orphaned) queue
            $query->whereNull('session_supervisor_id');
        }

        if (!empty($filters['status'])) {
            $query->where('status', $filters['status']);
        }
        if (!empty($filters['priority'])) {
            $query->where('priority', $filters['priority']);
        }
        if (!empty($filters['assigned_to'])) {
            $query->where('assigned_to', $filters['assigned_to']);
        }
        if (!empty($filters['session_supervisor_id'])) {
            $query->where('session_supervisor_id', $filters['session_supervisor_id']);
        }
        if (!empty($filters['sla_breached'])) {
            $query->where('sla_breached', true);
        }
        if (!empty($filters['search'])) {
            $search = $filters['search'];
            $query->where(function ($q) use ($search) {
                $q->where('ticket_number', 'ilike', "%{$search}%")
                  ->orWhere('subject', 'ilike', "%{$search}%")
                  ->orWhereHas('guardian', fn ($gq) => $gq->where('name', 'ilike', "%{$search}%")
                      ->orWhere('phone', 'ilike', "%{$search}%"));
            });
        }
        if (!empty($filters['tag_id'])) {
            $query->whereHas('tags', fn ($q) => $q->where('tags.id', $filters['tag_id']));
        }
        
        if (!empty($filters['type'])) {
            $type = $filters['type'];
            if ($type === 'students') {
                $query->whereHas('guardian', function ($q) {
                    $q->whereExists(function ($sub) {
                        $sub->select(DB::raw(1))
                            ->from('students')
                            ->whereColumn('students.whatsapp_number', 'guardians.phone');
                    });
                });
            } elseif ($type === 'teachers') {
                $query->whereHas('guardian', function ($q) {
                    $q->whereExists(function ($sub) {
                        $sub->select(DB::raw(1))
                            ->from('teachers')
                            ->whereColumn('teachers.whatsapp_number', 'guardians.phone');
                    });
                });
            } elseif ($type === 'unknown') {
                $query->whereHas('guardian', function ($q) {
                    $q->whereNotExists(function ($sub) {
                        $sub->select(DB::raw(1))
                            ->from('students')
                            ->whereColumn('students.whatsapp_number', 'guardians.phone');
                    })->whereNotExists(function ($sub) {
                        $sub->select(DB::raw(1))
                            ->from('teachers')
                            ->whereColumn('teachers.whatsapp_number', 'guardians.phone');
                    });
                });
            }
        }

        return $query->paginate($perPage);
    }

    /**
     * Get a single ticket with all relations.
     */
    public function show(int $ticketId): Ticket
    {
        return Ticket::with([
            'guardian', 'student', 'teacher', 'assignedTo', 'sessionSupervisor', 'tags',
            'messages' => fn ($q) => $q->with('replyToMessage.sentBy')->orderBy('timestamp'),
            'notes'    => fn ($q) => $q->with('user')->orderBy('created_at'),
            'logs'     => fn ($q) => $q->with('user')->orderBy('created_at', 'desc'),
        ])->findOrFail($ticketId);
    }

    /**
     * Reply to a ticket: create outbound WhatsApp message + dispatch send job.
     */
    public function reply(Ticket $ticket, int $userId, ?string $content = null, ?string $mediaUrl = null, ?string $replyToMessageId = null): WhatsappMessage
    {
        $guardian = $ticket->guardian;
        if (!$guardian) {
            throw new \RuntimeException('Ticket has no guardian to reply to');
        }

        $message = WhatsappMessage::create([
            'wa_message_id'       => 'out_' . Str::uuid(),
            'ticket_id'           => $ticket->id,
            'direction'           => MessageDirection::Outbound,
            'from_number'         => config('whatsapp.wasender.from_number', config('whatsapp.twilio.from_number')),
            'to_number'           => $guardian->phone,
            'message_type'        => $mediaUrl ? $this->detectMediaType($mediaUrl) : MessageType::Text,
            'content'             => $content,
            'media_url'           => $mediaUrl,
            'reply_to_message_id' => $replyToMessageId,
            'delivery_status'     => DeliveryStatus::Scheduled,
            'sent_by_id'          => $userId,
            'idempotency_key'     => Str::uuid()->toString(),
            'timestamp'           => now(),
        ]);

        // Update ticket
        $ticket->update([
            'last_message_preview' => Str::limit($content ?? 'Media Message', 100),
            'last_message_at'      => now(),
            'status'               => TicketStatus::Pending,
        ]);

        // Track first response time
        if (!$ticket->first_response_at) {
            $ticket->update(['first_response_at' => now()]);
        }

        // Dispatch send job
        SendWhatsAppMessageJob::dispatch($message->id);

        // Audit log
        $this->log($ticket, $userId, 'replied', details: Str::limit($content, 200));

        // Reload so DB-defaulted columns (created_at) are present in the response
        $message->refresh();

        // Trigger Event for frontend WebSockets
        event(new \App\Events\TicketMessageCreated($ticket, $message));

        return $message;
    }

    /**
     * Send an approved WhatsApp template to a contact (for new / out-of-session contacts).
     */
    public function replyWithTemplate(Ticket $ticket, int $userId, int $templateId, array $variables = []): WhatsappMessage
    {
        $guardian = $ticket->guardian;
        if (!$guardian) {
            throw new \RuntimeException('Ticket has no guardian to reply to');
        }

        $template = WhatsappTemplate::findOrFail($templateId);

        if ($template->status->value !== 'approved') {
            throw new \RuntimeException('Template is not approved yet');
        }

        // Resolve body preview for message preview (variables substituted)
        $bodyPreview = $template->resolvePreview($variables);

        $message = WhatsappMessage::create([
            'wa_message_id'       => 'out_' . Str::uuid(),
            'ticket_id'           => $ticket->id,
            'direction'           => MessageDirection::Outbound,
            'from_number'         => config('whatsapp.wasender.from_number', config('whatsapp.twilio.from_number')),
            'to_number'           => $guardian->phone,
            'message_type'        => MessageType::Text,
            'content'             => $bodyPreview,
            'template_name'       => $template->content_sid, // Twilio ContentSid (HXxxx)
            'template_variables'  => $variables,
            'delivery_status'     => DeliveryStatus::Scheduled,
            'sent_by_id'          => $userId,
            'idempotency_key'     => Str::uuid()->toString(),
            'timestamp'           => now(),
        ]);

        $ticket->update([
            'last_message_preview' => Str::limit($bodyPreview, 100),
            'last_message_at'      => now(),
            'status'               => TicketStatus::Pending,
        ]);

        if (!$ticket->first_response_at) {
            $ticket->update(['first_response_at' => now()]);
        }

        SendWhatsAppMessageJob::dispatch($message->id);

        $this->log($ticket, $userId, 'template_sent', details: $template->name);

        $message->refresh();

        event(new \App\Events\TicketMessageCreated($ticket, $message));

        return $message;
    }

    /**
     * Detect media type from URL extension.
     */
    private function detectMediaType(string $url): MessageType
    {
        $ext = strtolower(pathinfo(parse_url($url, PHP_URL_PATH), PATHINFO_EXTENSION));

        $audioExts = ['m4a', 'mp3', 'ogg', 'wav', 'aac', 'opus', 'amr'];
        $docExts   = ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'csv', 'zip', 'rar'];

        if (in_array($ext, $audioExts)) return MessageType::Audio;
        if (in_array($ext, $docExts))   return MessageType::Document;

        return MessageType::Image;
    }

    /**
     * Assign ticket to a supervisor.
     */
    public function assign(Ticket $ticket, int $assigneeId, int $assigner): Ticket
    {
        $oldAssigned = $ticket->assigned_to;

        $ticket->update(['assigned_to' => $assigneeId]);

        $this->log($ticket, $assigner, 'assigned',
            old: $oldAssigned ? (string) $oldAssigned : null,
            new: (string) $assigneeId
        );

        return $ticket->refresh()->load('assignedTo');
    }

    /**
     * Update ticket status.
     */
    public function updateStatus(Ticket $ticket, TicketStatus $status, int $userId): Ticket
    {
        $oldStatus = $ticket->status->value;

        $updates = ['status' => $status];

        if ($status === TicketStatus::Resolved) {
            $updates['resolved_at'] = now();
        }
        if ($status === TicketStatus::Closed) {
            $updates['closed_at'] = now();
        }

        $ticket->update($updates);

        $this->log($ticket, $userId, 'status_changed', old: $oldStatus, new: $status->value);

        return $ticket->refresh();
    }

    /**
     * Escalate a ticket (increase level).
     */
    public function escalate(Ticket $ticket, int $userId, ?string $reason = null): Ticket
    {
        $oldLevel = $ticket->escalation_level;
        $ticket->update([
            'escalation_level' => $oldLevel + 1,
            'priority' => TicketPriority::Urgent,
        ]);

        $this->log($ticket, $userId, 'escalated',
            old: (string) $oldLevel,
            new: (string) ($oldLevel + 1),
            details: $reason
        );

        return $ticket->refresh();
    }

    /**
     * Add internal note to ticket.
     */
    public function addNote(Ticket $ticket, int $userId, string $content): TicketNote
    {
        $note = TicketNote::create([
            'ticket_id'   => $ticket->id,
            'user_id'     => $userId,
            'content'     => $content,
            'is_internal' => true,
        ]);

        $this->log($ticket, $userId, 'note_added');

        return $note->load('user');
    }

    /**
     * Get dashboard stats, optionally scoped by supervisor.
     */
    public function stats(?int $userId = null, ?User $viewer = null): array
    {
        $query = Ticket::query();

        // Role-based scoping for stats
        if ($viewer && $viewer->hasRole('supervisor', 'api') && !$viewer->hasAnyRole(['admin', 'senior_supervisor'], 'api')) {
            $query->where('session_supervisor_id', $viewer->id);
        } elseif ($userId) {
            $query->where('assigned_to', $userId);
        }

        $studentsCount = (clone $query)->whereHas('guardian', function ($q) {
            $q->whereExists(function ($sub) {
                $sub->select(DB::raw(1))->from('students')->whereColumn('students.whatsapp_number', 'guardians.phone');
            });
        })->count();

        $teachersCount = (clone $query)->whereHas('guardian', function ($q) {
            $q->whereExists(function ($sub) {
                $sub->select(DB::raw(1))->from('teachers')->whereColumn('teachers.whatsapp_number', 'guardians.phone');
            });
        })->count();

        $unknownCount = (clone $query)->whereHas('guardian', function ($q) {
            $q->whereNotExists(function ($sub) {
                $sub->select(DB::raw(1))->from('students')->whereColumn('students.whatsapp_number', 'guardians.phone');
            })->whereNotExists(function ($sub) {
                $sub->select(DB::raw(1))->from('teachers')->whereColumn('teachers.whatsapp_number', 'guardians.phone');
            });
        })->count();

        // Unassigned count (only meaningful for admins)
        $unassignedCount = ($viewer && $viewer->hasAnyRole(['admin', 'senior_supervisor'], 'api'))
            ? Ticket::whereNull('session_supervisor_id')
                ->whereNotIn('status', ['resolved', 'closed'])
                ->count()
            : 0;

        return [
            'open'              => (clone $query)->where('status', TicketStatus::Open)->count(),
            'pending'           => (clone $query)->where('status', TicketStatus::Pending)->count(),
            'resolved'          => (clone $query)->where('status', TicketStatus::Resolved)->count(),
            'students'          => $studentsCount,
            'teachers'          => $teachersCount,
            'unknown'           => $unknownCount,
            'unassigned'        => $unassignedCount,
            'sla_breached'      => (clone $query)->where('sla_breached', true)
                                               ->whereNotIn('status', [TicketStatus::Closed])->count(),
            'today_total'       => Ticket::whereDate('created_at', today())->count(),
            'avg_response_minutes' => Ticket::whereNotNull('first_response_at')
                ->whereDate('created_at', '>=', now()->subDays(7))
                ->selectRaw('AVG(TIMESTAMPDIFF(MINUTE, created_at, first_response_at)) as avg_min')
                ->value('avg_min') ?? 0,
        ];
    }

    /**
     * Create an audit log entry.
     */
    private function log(Ticket $ticket, int $userId, string $action, ?string $old = null, ?string $new = null, ?string $details = null): void
    {
        TicketLog::create([
            'ticket_id' => $ticket->id,
            'user_id'   => $userId,
            'action'    => $action,
            'old_value' => $old,
            'new_value' => $new,
            'details'   => $details,
        ]);
    }
}
