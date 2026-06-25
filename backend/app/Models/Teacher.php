<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Teacher extends Model
{
    use SoftDeletes;

    protected static function booted()
    {
        static::saved(function ($teacher) {
            \App\Models\Guardian::where('phone', $teacher->whatsapp_number)
                ->update(['name' => $teacher->name]);
        });
    }

    protected $fillable = ['name', 'whatsapp_number', 'zoom_link', 'reminders_paused'];

    protected $casts = ['reminders_paused' => 'boolean'];

    public function sessions(): HasMany
    {
        return $this->hasMany(ClassSession::class);
    }
}
