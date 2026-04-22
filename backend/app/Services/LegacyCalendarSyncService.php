<?php

namespace App\Services;

use App\Models\CalendarTeacher;
use App\Models\CalendarTeacherTimetable;
use App\Models\CalendarExceptionalClass;
use App\Models\CalendarStudentStop;
use App\Models\ClassSession;
use App\Models\Student;
use App\Models\Teacher;
use Carbon\Carbon;
use Illuminate\Support\Facades\Log;

class LegacyCalendarSyncService
{
    /**
     * Generate class sessions for the next $daysToLookAhead days.
     */
    public function syncFutureDays(int $daysToLookAhead = 7): void
    {
        for ($i = 0; $i <= $daysToLookAhead; $i++) {
            $date = Carbon::now()->addDays($i);
            $this->syncDate($date);
        }
    }

    /**
     * Sync a specific date from legacy calendar to class_sessions.
     */
    public function syncDate(Carbon $date): void
    {
        $dateString = $date->format('Y-m-d');
        $dayOfWeekName = $date->format('l'); // e.g. "Monday"

        // 1. Get stopped students for this date
        $stoppedStudents = CalendarStudentStop::where('date_from', '<=', $dateString)
            ->where('date_to', '>=', $dateString)
            ->pluck('student_name')
            ->toArray();

        // 2. Fetch standard recurring timetables for this day of the week
        $timetables = CalendarTeacherTimetable::with('teacher')
            ->where('day', $dayOfWeekName)
            ->where('status', 'active')
            ->where(function ($query) {
                $query->whereNull('deleted_date')
                    ->orWhere('deleted_date', '>', Carbon::now()->format('Y-m-d'));
            })
            ->whereNotIn('student_name', $stoppedStudents)
            ->get();

        foreach ($timetables as $timetable) {
            $this->createSessionFromTimetable($timetable, $date);
        }

        // 3. Fetch exceptional classes specifically scheduled for this date
        $exceptionalClasses = CalendarExceptionalClass::with('teacher')
            ->where('date', $dateString)
            ->get();

        foreach ($exceptionalClasses as $exceptional) {
            $this->createSessionFromExceptional($exceptional, $date);
        }
    }

    private function createSessionFromTimetable(CalendarTeacherTimetable $timetable, Carbon $date): void
    {
        $sessionDate = $date->format('Y-m-d');
        $startTime = $timetable->start_time;
        // Default end time to 1 hour later if not provided.
        $endTime = $timetable->finish_time ?: Carbon::parse($startTime)->addHour()->format('H:i:s');
        
        $teacherId = $this->resolveGlobalTeacherId($timetable->teacher);
        $studentId = $this->resolveGlobalStudentId($timetable->student_name);

        if (!$teacherId || !$studentId) {
            Log::warning("Skipping sync for legacy timetable ID {$timetable->id}: Unresolved Teacher or Student mapping.", [
                'student_name' => $timetable->student_name,
                'calendar_teacher' => $timetable->teacher?->name
            ]);
            return;
        }

        // Use firstOrCreate to prevent duplicates perfectly
        ClassSession::firstOrCreate(
            [
                'session_date' => $sessionDate,
                'start_time' => $startTime,
                'student_id' => $studentId,
                'teacher_id' => $teacherId,
            ],
            [
                'end_time' => $endTime,
                'title' => "Legacy Class: " . $timetable->student_name,
                'status' => 'scheduled',
            ]
        );
    }

    private function createSessionFromExceptional(CalendarExceptionalClass $exceptional, Carbon $date): void
    {
        $sessionDate = $date->format('Y-m-d');
        $startTime = $exceptional->time;
        $endTime = Carbon::parse($startTime)->addHour()->format('H:i:s'); // Exceptional classes often lack explicit end times
        
        $teacherId = $this->resolveGlobalTeacherId($exceptional->teacher);
        $studentId = $this->resolveGlobalStudentId($exceptional->student_name);

        if (!$teacherId || !$studentId) {
            Log::warning("Skipping sync for legacy exceptional class ID {$exceptional->id}: Unresolved mapping.");
            return;
        }

        ClassSession::firstOrCreate(
            [
                'session_date' => $sessionDate,
                'start_time' => $startTime,
                'student_id' => $studentId,
                'teacher_id' => $teacherId,
            ],
            [
                'end_time' => $endTime,
                'title' => "Exceptional Class: " . $exceptional->student_name,
                'status' => 'scheduled',
            ]
        );
    }

    /**
     * Delete sessions that match a new student stop period.
     */
    public function syncStopsForStudent(string $studentName, string $dateFrom, string $dateTo): void
    {
        $studentId = $this->resolveGlobalStudentId($studentName);
        if (!$studentId) return;

        // Any sessions scheduled between these dates should be marked cancelled
        ClassSession::where('student_id', $studentId)
            ->whereBetween('session_date', [$dateFrom, $dateTo])
            ->whereIn('status', ['scheduled', 'pending'])
            ->update([
                'status' => 'cancelled',
                'cancellation_reason' => 'Legacy Calendar Student Stop Created',
            ]);
    }

    // --- Helpers to resolve DB links ---

    private function resolveGlobalTeacherId(?CalendarTeacher $legacyTeacher): ?int
    {
        if (!$legacyTeacher || !$legacyTeacher->name) return null;
        
        $teacher = Teacher::where('name', $legacyTeacher->name)->first();
        return $teacher ? $teacher->id : null;
    }

    private function resolveGlobalStudentId(?string $studentName): ?int
    {
        if (!$studentName) return null;
        
        $student = Student::where('name', $studentName)->first();
        return $student ? $student->id : null;
    }
}
