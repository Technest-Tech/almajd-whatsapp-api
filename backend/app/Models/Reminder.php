<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Reminder extends Model
{
    protected $fillable = [
        'type', 'recipient_type', 'reminder_phase', 'class_session_id',
        'recipient_phone', 'recipient_name',
        'template_name', 'message_body', 'scheduled_at', 'sent_at',
        'status', 'confirmation_status', 'failure_reason',
    ];

    protected function casts(): array
    {
        return [
            'scheduled_at' => 'datetime',
            'sent_at'      => 'datetime',
        ];
    }

    public function classSession(): BelongsTo
    {
        return $this->belongsTo(ClassSession::class);
    }
}
