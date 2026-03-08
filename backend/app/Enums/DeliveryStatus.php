<?php

declare(strict_types=1);

namespace App\Enums;

enum DeliveryStatus: string
{
    case Scheduled  = 'scheduled';
    case Queued     = 'queued';
    case Accepted   = 'accepted';
    case Sending    = 'sending';
    case Sent       = 'sent';
    case Delivered  = 'delivered';
    case Read       = 'read';
    case Undelivered = 'undelivered';
    case Failed     = 'failed';
    case Receiving  = 'receiving';
    case Received   = 'received';
}
