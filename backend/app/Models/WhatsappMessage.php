<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\DeliveryStatus;
use App\Enums\MessageDirection;
use App\Enums\MessageType;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class WhatsappMessage extends Model
{
    public $timestamps = false;

    protected $fillable = [
        'wa_message_id', 'ticket_id', 'direction', 'from_number', 'to_number',
        'message_type', 'content', 'media_url', 'media_mime_type',
        'template_name', 'delivery_status', 'failure_reason', 'retry_count',
        'idempotency_key', 'sent_by_id', 'timestamp',
    ];

    protected function casts(): array
    {
        return [
            'direction'       => MessageDirection::class,
            'message_type'    => MessageType::class,
            'delivery_status' => DeliveryStatus::class,
            'timestamp'       => 'datetime',
            'created_at'      => 'datetime',
            'retry_count'     => 'integer',
        ];
    }

    public function ticket(): BelongsTo
    {
        return $this->belongsTo(Ticket::class);
    }

    public function sentBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'sent_by_id');
    }

    public function deliveryLogs(): HasMany
    {
        return $this->hasMany(DeliveryLog::class, 'message_id');
    }
}
