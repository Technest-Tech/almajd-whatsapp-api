<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Teacher extends Model
{
    use SoftDeletes;

    protected $fillable = ['name', 'phone', 'email', 'notes'];

    public function sessions(): HasMany
    {
        return $this->hasMany(ClassSession::class);
    }
}
