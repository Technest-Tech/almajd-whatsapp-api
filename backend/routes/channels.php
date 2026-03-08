<?php

use Illuminate\Support\Facades\Broadcast;

/*
|--------------------------------------------------------------------------
| Broadcast Channels
|--------------------------------------------------------------------------
| Private and presence channels for real-time push via Laravel Reverb.
| Guard is explicitly 'api' because permissions are seeded under that guard.
*/

Broadcast::channel('user.{userId}', function ($user, $userId) {
    return (int) $user->id === (int) $userId;
});

Broadcast::channel('supervisors', function ($user) {
    if ($user->hasAnyRole(['supervisor', 'senior_supervisor', 'admin'])) {
        return ['id' => $user->id, 'name' => $user->name];
    }
    return false;
});

Broadcast::channel('admin', function ($user) {
    return $user->hasRole('admin');
});

Broadcast::channel('ticket.{ticketId}', function ($user, $ticketId) {
    return $user->hasPermissionTo('tickets.view', 'api');
});
