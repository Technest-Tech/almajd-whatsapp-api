<?php

declare(strict_types=1);

namespace App\Events;

use App\Models\WhatsappMessage;
use Illuminate\Broadcasting\PrivateChannel;

class TicketMessageStatusUpdated extends BaseRealtimeEvent
{
    public function __construct(
        public readonly WhatsappMessage $message
    ) {}

    public function eventType(): string
    {
        return 'ticket.message_status_updated';
    }

    public function payload(): array
    {
        return [
            'id'              => $this->message->id,
            'delivery_status' => $this->message->delivery_status,
        ];
    }

    public function broadcastAs(): string
    {
        return 'TicketMessageStatusUpdated';
    }

    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('ticket.' . $this->message->ticket_id),
        ];
    }
}
