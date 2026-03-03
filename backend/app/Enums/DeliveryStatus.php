<?php

declare(strict_types=1);

namespace App\Enums;

enum DeliveryStatus: string
{
    case Scheduled = 'scheduled';
    case Sent = 'sent';
    case Delivered = 'delivered';
    case Read = 'read';
    case Failed = 'failed';
}
