<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class TicketNote extends Model
{
    public $timestamps = false;

    protected $fillable = ['ticket_id', 'user_id', 'content', 'is_internal'];

    protected function casts(): array
    {
        return [
            'is_internal' => 'boolean',
            'created_at'  => 'datetime',
        ];
    }

    public function ticket(): BelongsTo
    {
        return $this->belongsTo(Ticket::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
