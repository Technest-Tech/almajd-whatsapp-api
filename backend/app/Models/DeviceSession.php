<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DeviceSession extends Model
{
    public $timestamps = false;

    protected $fillable = [
        'user_id',
        'device_id',
        'device_name',
        'fcm_token',
        'refresh_token',
        'last_active_at',
        'expires_at',
    ];

    protected function casts(): array
    {
        return [
            'last_active_at' => 'datetime',
            'expires_at'     => 'datetime',
            'created_at'     => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
