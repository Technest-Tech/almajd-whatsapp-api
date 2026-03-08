<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\TicketPriority;
use App\Enums\TicketStatus;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Ticket extends Model
{
    protected $fillable = [
        'ticket_number', 'guardian_id', 'student_id', 'assigned_to',
        'status', 'priority', 'channel', 'subject', 'last_message_preview',
        'last_message_at', 'unread_count',
        'escalation_level', 'first_response_at', 'resolved_at', 'closed_at',
        'sla_deadline_at', 'sla_breached',
    ];

    protected function casts(): array
    {
        return [
            'status'            => TicketStatus::class,
            'priority'          => TicketPriority::class,
            'escalation_level'  => 'integer',
            'sla_breached'      => 'boolean',
            'first_response_at' => 'datetime',
            'resolved_at'       => 'datetime',
            'closed_at'         => 'datetime',
            'sla_deadline_at'   => 'datetime',
            'last_message_at'   => 'datetime',
        ];
    }

    // ── Relationships ────────────────────────────────────

    public function guardian(): BelongsTo
    {
        return $this->belongsTo(Guardian::class);
    }

    public function student(): BelongsTo
    {
        return $this->belongsTo(Student::class);
    }

    public function assignedTo(): BelongsTo
    {
        return $this->belongsTo(User::class, 'assigned_to');
    }

    public function tags(): BelongsToMany
    {
        return $this->belongsToMany(Tag::class, 'ticket_tag');
    }

    public function messages(): HasMany
    {
        return $this->hasMany(WhatsappMessage::class);
    }

    public function notes(): HasMany
    {
        return $this->hasMany(TicketNote::class);
    }

    public function logs(): HasMany
    {
        return $this->hasMany(TicketLog::class);
    }

    // ── Helpers ──────────────────────────────────────────

    public static function generateTicketNumber(): string
    {
        $date = now()->format('ymd');
        $count = static::whereDate('created_at', today())->count() + 1;
        return "TKT-{$date}-" . str_pad((string) $count, 4, '0', STR_PAD_LEFT);
    }
}
