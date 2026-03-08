<?php

declare(strict_types=1);

namespace App\Enums;

enum TemplateStatus: string
{
    case Draft     = 'draft';      // Saved locally, not sent to Twilio yet
    case Pending   = 'pending';    // Submitted to Twilio/Meta, awaiting approval
    case Approved  = 'approved';   // Approved by Meta — ready to send
    case Rejected  = 'rejected';   // Rejected by Meta
}
