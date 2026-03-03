<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Tag extends Model
{
    protected $fillable = ['name', 'color', 'sla_first_response_minutes', 'sla_resolution_minutes'];

    protected function casts(): array
    {
        return [
            'sla_first_response_minutes' => 'integer',
            'sla_resolution_minutes'     => 'integer',
        ];
    }

    public function tickets()
    {
        return $this->belongsToMany(Ticket::class, 'ticket_tag');
    }
}
