<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Student extends Model
{
    use SoftDeletes;

    protected $fillable = ['name', 'guardian_id', 'phone', 'student_code', 'notes'];

    public function guardian(): BelongsTo
    {
        return $this->belongsTo(Guardian::class);
    }

    public function scheduleEntries(): HasMany
    {
        return $this->hasMany(ScheduleEntry::class)->orderBy('day_of_week')->orderBy('start_time');
    }

    public function classSessions(): HasMany
    {
        return $this->hasMany(ClassSession::class)->orderBy('session_date')->orderBy('start_time');
    }
}
