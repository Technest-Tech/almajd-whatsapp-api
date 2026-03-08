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
        'idempotency_key', 'sent_by_id', 'timestamp', 'reply_to_message_id',
    ];

    protected $appends = [
        'reply_to_id', 'reply_to_body', 'reply_to_sender', 'reply_to_type'
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

    public function replyToMessage(): BelongsTo
    {
        return $this->belongsTo(WhatsappMessage::class, 'reply_to_message_id');
    }

    public function getReplyToIdAttribute(): ?int
    {
        return $this->reply_to_message_id ? (int) $this->reply_to_message_id : null;
    }

    public function getReplyToBodyAttribute(): ?string
    {
        return $this->replyToMessage?->content;
    }

    public function getReplyToSenderAttribute(): ?string
    {
        if (!$this->replyToMessage) return null;
        return $this->replyToMessage->direction === MessageDirection::Inbound 
            ? ($this->ticket?->guardian?->name ?? 'المستخدم') 
            : ($this->replyToMessage->sentBy?->name ?? 'الدعم');
    }

    public function getReplyToTypeAttribute(): ?string
    {
        return $this->replyToMessage?->message_type?->value;
    }

    public function deliveryLogs(): HasMany
    {
        return $this->hasMany(DeliveryLog::class, 'message_id');
    }
}
