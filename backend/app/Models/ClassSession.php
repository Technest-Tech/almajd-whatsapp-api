<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ClassSession extends Model
{
    protected $fillable = [
        'schedule_entry_id', 'student_id', 'teacher_id', 'supervisor_id', 'title', 'session_date',
        'start_time', 'end_time', 'status', 'attendance_status', 'cancellation_reason',
        'rescheduled_date', 'rescheduled_start_time', 'rescheduled_end_time',
        'teacher_report', 'report_status', 'report_nudge_count',
    ];

    protected function casts(): array
    {
        return [
            'session_date' => 'date',
            'rescheduled_date' => 'date',
        ];
    }

    public function scheduleEntry(): BelongsTo
    {
        return $this->belongsTo(ScheduleEntry::class);
    }

    public function student(): BelongsTo
    {
        return $this->belongsTo(Student::class);
    }

    public function teacher(): BelongsTo
    {
        return $this->belongsTo(Teacher::class);
    }

    public function supervisor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'supervisor_id');
    }
}
