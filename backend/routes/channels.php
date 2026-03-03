<?php

use Illuminate\Support\Facades\Broadcast;

/*
|--------------------------------------------------------------------------
| Broadcast Channels
|--------------------------------------------------------------------------
| Private and presence channels for real-time push via Laravel Reverb.
*/

// Private channel: each user gets their own channel for ticket updates
Broadcast::channel('user.{userId}', function ($user, $userId) {
    return (int) $user->id === (int) $userId;
});

// Presence channel: all supervisors + admin
Broadcast::channel('supervisors', function ($user) {
    if ($user->hasAnyRole(['supervisor', 'senior_supervisor', 'admin'])) {
        return ['id' => $user->id, 'name' => $user->name];
    }
    return false;
});

// Private channel: admin-only notifications
Broadcast::channel('admin', function ($user) {
    return $user->hasRole('admin');
});
