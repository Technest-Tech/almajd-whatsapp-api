<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Guardian extends Model
{
    use SoftDeletes;

    protected $fillable = ['name', 'phone', 'email', 'notes'];

    public function students(): HasMany
    {
        return $this->hasMany(Student::class, 'whatsapp_number', 'phone');
    }

    public function tickets(): HasMany
    {
        return $this->hasMany(Ticket::class);
    }
}
