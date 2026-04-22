<?php

declare(strict_types=1);

namespace App\Events;

use App\Models\Ticket;
use App\Models\WhatsappMessage;
use Illuminate\Broadcasting\PrivateChannel;

class TicketMessageCreated extends BaseRealtimeEvent
{
    public function __construct(
        public readonly Ticket $ticket,
        public readonly WhatsappMessage $message
    ) {}

    public function eventType(): string
    {
        return 'ticket.message_created';
    }

    public function payload(): array
    {
        return collect($this->message->toArray())
            ->except(['from_number', 'to_number'])
            ->toArray();
    }

    public function broadcastAs(): string
    {
        return 'TicketMessageCreated';
    }

    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('ticket.' . $this->ticket->id),
            new PrivateChannel('tickets'),
        ];
    }
}
