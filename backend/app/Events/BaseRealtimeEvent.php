<?php

declare(strict_types=1);

namespace App\Events;

use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Broadcasting\PresenceChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

abstract class BaseRealtimeEvent implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    /**
     * The event type identifier sent to clients.
     */
    abstract public function eventType(): string;

    /**
     * Data payload to broadcast.
     */
    abstract public function payload(): array;

    /**
     * Final broadcast payload: includes type + data for client-side routing.
     */
    public function broadcastWith(): array
    {
        return [
            'type' => $this->eventType(),
            'data' => $this->payload(),
            'timestamp' => now()->toISOString(),
        ];
    }

    /**
     * Use the queue for broadcasting so it doesn't block the request.
     */
    public $broadcastQueue = 'default';
}
