<?php

declare(strict_types=1);

namespace App\Enums;

enum UserAvailability: string
{
    case Available = 'available';
    case Busy = 'busy';
    case Unavailable = 'unavailable';
}
