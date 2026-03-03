<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\TemplateStatus;
use Illuminate\Database\Eloquent\Model;

class WhatsappTemplate extends Model
{
    protected $fillable = [
        'name', 'language', 'category', 'body_template', 'header_type', 'status',
    ];

    protected function casts(): array
    {
        return [
            'status' => TemplateStatus::class,
        ];
    }
}
