<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CalendarTeacherTimetable extends Model
{
    protected $table = 'calendar_teacher_timetables';

    protected $fillable = [
        'teacher_id',
        'day',
        'start_time',
        'finish_time',
        'student_name',
        'country',
        'status',
        'reactive_date',
        'deleted_date',
    ];

    protected function casts(): array
    {
        return [
            'reactive_date' => 'date',
            'deleted_date' => 'date',
        ];
    }

    /**
     * Get the teacher for this timetable entry
     */
    public function teacher(): BelongsTo
    {
        return $this->belongsTo(CalendarTeacher::class, 'teacher_id');
    }
}
