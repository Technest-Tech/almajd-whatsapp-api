<?php

declare(strict_types=1);

namespace App\Enums;

enum TemplateStatus: string
{
    case Approved = 'approved';
    case Pending = 'pending';
    case Rejected = 'rejected';
}
