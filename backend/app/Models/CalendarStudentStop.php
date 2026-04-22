<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class CalendarStudentStop extends Model
{
    protected $table = 'calendar_students_stops';

    protected $fillable = [
        'student_name',
        'date_from',
        'date_to',
        'reason',
    ];

    protected function casts(): array
    {
        return [
            'date_from' => 'date',
            'date_to' => 'date',
        ];
    }
}
