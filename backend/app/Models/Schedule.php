<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasManyThrough;

class Schedule extends Model
{
    protected $fillable = [
        'student_id', 'name', 'description',
        'start_date', 'end_date', 'is_active',
    ];

    protected function casts(): array
    {
        return [
            'start_date' => 'date',
            'end_date'   => 'date',
            'is_active'  => 'boolean',
        ];
    }

    public function student(): BelongsTo
    {
        return $this->belongsTo(Student::class);
    }

    public function entries(): HasMany
    {
        return $this->hasMany(ScheduleEntry::class)
            ->orderBy('day_of_week')
            ->orderBy('start_time');
    }

    /** All class sessions generated from this schedule's entries */
    public function classSessions(): HasManyThrough
    {
        return $this->hasManyThrough(ClassSession::class, ScheduleEntry::class);
    }
}
