<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CalendarExceptionalClass extends Model
{
    protected $table = 'calendar_exceptional_classes';

    protected $fillable = [
        'student_name',
        'student_id',
        'date',
        'time',
        'teacher_id',
    ];

    protected function casts(): array
    {
        return [
            'date' => 'date',
        ];
    }

    /**
     * Get the teacher for this exceptional class
     */
    public function teacher(): BelongsTo
    {
        return $this->belongsTo(CalendarTeacher::class, 'teacher_id');
    }

    /**
     * Get the linked new-system student (if mapped)
     */
    public function student(): BelongsTo
    {
        return $this->belongsTo(Student::class, 'student_id');
    }

    /**
     * Format time accessor
     */
    public function getFormattedTimeAttribute(): string
    {
        return $this->time ? date('g:i A', strtotime($this->time)) : '';
    }
}
