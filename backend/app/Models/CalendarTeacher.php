<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class CalendarTeacher extends Model
{
    protected $table = 'calendar_teachers';

    protected $fillable = [
        'name',
        'whatsapp',
    ];

    /**
     * Get the timetable entries for this teacher
     */
    public function timetables(): HasMany
    {
        return $this->hasMany(CalendarTeacherTimetable::class, 'teacher_id');
    }

    /**
     * Get the exceptional classes for this teacher
     */
    public function exceptionalClasses(): HasMany
    {
        return $this->hasMany(CalendarExceptionalClass::class, 'teacher_id');
    }
}
