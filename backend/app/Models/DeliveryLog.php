<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\DeliveryStatus;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DeliveryLog extends Model
{
    public $timestamps = false;

    protected $fillable = [
        'message_id', 'reminder_job_id', 'status', 'bsp_response',
        'failure_reason', 'attempted_at',
    ];

    protected function casts(): array
    {
        return [
            'status'       => DeliveryStatus::class,
            'bsp_response' => 'array',
            'attempted_at' => 'datetime',
        ];
    }

    public function message(): BelongsTo
    {
        return $this->belongsTo(WhatsappMessage::class, 'message_id');
    }
}
