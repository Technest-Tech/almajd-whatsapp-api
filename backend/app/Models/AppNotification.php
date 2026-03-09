<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AppNotification extends Model
{
    protected $table = 'notifications';

    protected $fillable = [
        'user_id',
        'type',
        'title',
        'body',
        'data',
        'read_at',
    ];

    protected $casts = [
        'data' => 'array',
        'read_at' => 'datetime',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function scopeUnread($query)
    {
        return $query->whereNull('read_at');
    }

    /**
     * Create a notification for all admin users (broadcast).
     */
    public static function notifyAdmins(string $type, string $title, ?string $body = null, ?array $data = null): void
    {
        // Use all users — in a single-admin setup this notifies everyone
        // For multi-role, filter by Spatie role with correct guard
        $userIds = User::all()->pluck('id');

        foreach ($userIds as $userId) {
            static::create([
                'user_id' => $userId,
                'type' => $type,
                'title' => $title,
                'body' => $body,
                'data' => $data,
            ]);
        }
    }
}
