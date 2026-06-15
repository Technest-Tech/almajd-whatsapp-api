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

    /**
     * Generate class sessions for the next $daysToLookAhead days for a specific student.
     */
    public function syncStudentFutureDays(string $studentName, int $daysToLookAhead = 90): void
    {
        $studentId = $this->resolveGlobalStudentId($studentName);
        if (!$studentId) return;

        // 1. Delete all future 'scheduled' OR 'coming' sessions for this student
        // This clears out any sessions from old timetable configurations.
        // 'coming' sessions are included because auto-schedule transitions them
        // from 'scheduled' → 'coming', so a second sync would otherwise skip them
        // and create duplicates alongside the existing coming sessions.
        // Completed/cancelled/rescheduled history is preserved.
        ClassSession::where('student_id', $studentId)
            ->where('session_date', '>=', Carbon::today()->format('Y-m-d'))
            ->whereIn('status', ['scheduled', 'coming'])
            ->delete();

        // 2. Rebuild sessions from today to +90 days
        for ($i = 0; $i <= $daysToLookAhead; $i++) {
            $date = Carbon::today()->addDays($i);
            $this->syncDateForStudent($date, $studentName);
        }
    }

    /**
     * Sync a specific date from legacy calendar to class_sessions for a specific student.
     */
    public function syncDateForStudent(Carbon $date, string $studentName): void
    {
        $dateString = $date->format('Y-m-d');
        $dayOfWeekName = $date->format('l');

        // 1. Check if student is stopped on this date
        $isStopped = CalendarStudentStop::where('student_name', $studentName)
            ->where('date_from', '<=', $dateString)
            ->where('date_to', '>=', $dateString)
            ->exists();
            
        if ($isStopped) return; // Skip generating if stopped

        // 2. Fetch standard recurring timetables for this student
        $timetables = CalendarTeacherTimetable::with('teacher')
            ->where('student_name', $studentName)
            ->where('day', $dayOfWeekName)
            ->where('status', 'active')
            ->where(function ($query) {
                $query->whereNull('deleted_date')
                    ->orWhere('deleted_date', '>', Carbon::now()->format('Y-m-d'));
            })
            ->get();

        foreach ($timetables as $timetable) {
            $this->createSessionFromTimetable($timetable, $date);
        }

        // 3. Fetch exceptional classes specifically scheduled for this date & student
        $exceptionalClasses = CalendarExceptionalClass::with('teacher')
            ->where('student_name', $studentName)
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

        // ── Prefer the direct student_id link (set via UI mapping) ──────────
        $studentId = $timetable->student_id
            ?? $this->resolveGlobalStudentId($timetable->student_name);

        if (!$teacherId || !$studentId) {
            Log::warning("Skipping sync for legacy timetable ID {$timetable->id}: Unresolved Teacher or Student mapping.", [
                'student_name' => $timetable->student_name,
                'calendar_teacher' => $timetable->teacher?->name
            ]);
            return;
        }

        $this->upsertSession($sessionDate, $startTime, $studentId, $teacherId, $endTime, $timetable->student_name);
    }

    private function createSessionFromExceptional(CalendarExceptionalClass $exceptional, Carbon $date): void
    {
        $sessionDate = $date->format('Y-m-d');
        $startTime = $exceptional->time;
        $endTime = Carbon::parse($startTime)->addHour()->format('H:i:s');

        $teacherId = $this->resolveGlobalTeacherId($exceptional->teacher);

        // ── Prefer the direct student_id link (set via UI mapping) ──────────
        $studentId = $exceptional->student_id
            ?? $this->resolveGlobalStudentId($exceptional->student_name);

        if (!$teacherId || !$studentId) {
            Log::warning("Skipping sync for legacy exceptional class ID {$exceptional->id}: Unresolved mapping.");
            return;
        }

        $this->upsertSession($sessionDate, $startTime, $studentId, $teacherId, $endTime, $exceptional->student_name);
    }

    /**
     * Insert a session only if none exists for this slot.
     * Uses INSERT IGNORE so concurrent sync runs can never produce duplicate rows,
     * even if they both pass the SELECT check before either has committed.
     */
    private function upsertSession(
        string $sessionDate,
        string $startTime,
        int    $studentId,
        int    $teacherId,
        string $endTime,
        string $title,
    ): void {
        try {
            ClassSession::firstOrCreate(
                [
                    'session_date' => $sessionDate,
                    'start_time'   => $startTime,
                    'student_id'   => $studentId,
                    'teacher_id'   => $teacherId,
                ],
                [
                    'end_time' => $endTime,
                    'title'    => $title,
                    'status'   => 'scheduled',
                ]
            );
        } catch (\Illuminate\Database\UniqueConstraintViolationException) {
            // Another concurrent request inserted the same slot first — that's fine, skip silently.
        }
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

        // Tier 1 — exact raw match.
        $teacher = Teacher::where('name', $legacyTeacher->name)->first();
        if ($teacher) return $teacher->id;

        // The legacy calendar and the teachers table frequently spell the same name
        // differently — mostly taa-marbuta (ة/ه), hamza/alef (أإآ→ا), alef-maqsura
        // (ى→ي), and a "معلم/معلمة/معلمه" honorific prefix. Substring LIKE matching
        // could neither bridge those nor match a short global name ("زهراء") against a
        // longer calendar name ("زهراء سامي"), so these teachers' sessions were silently
        // skipped. We normalize BOTH sides and match on the normalized name instead.
        $needle = $this->normalizeName($legacyTeacher->name);
        if ($needle === '') return null;

        $teachers = Teacher::all(['id', 'name']);
        $normMap = [];
        foreach ($teachers as $t) {
            $normMap[$t->id] = $this->normalizeName($t->name);
        }

        // Tier 2 — exact normalized match.
        foreach ($normMap as $id => $norm) {
            if ($norm !== '' && $norm === $needle) {
                return $id;
            }
        }

        // Tier 3 — normalized containment, accepted ONLY when exactly one teacher
        // matches. This recovers shortened names ("زهراء سامي" → "زهراء") while
        // refusing ambiguous first-name collisions ("اسامة" → 3 candidates) that
        // would otherwise route reminders to the wrong teacher's WhatsApp number.
        $contained = [];
        foreach ($normMap as $id => $norm) {
            if ($norm === '') continue;
            if (str_contains($needle, $norm) || str_contains($norm, $needle)) {
                $contained[$id] = true;
            }
        }
        if (count($contained) === 1) {
            return array_key_first($contained);
        }

        Log::warning("LegacySync: Unresolved teacher mapping for calendar name '{$legacyTeacher->name}' (normalized '{$needle}') — create the teacher or align the name.");

        return null;
    }

    /**
     * Normalize an Arabic teacher name for cross-source matching: strip the
     * "معلم/معلمة/معلمه" honorific prefix, fold hamza/alef and taa-marbuta/alef-maqsura
     * variants, and collapse whitespace.
     */
    private function normalizeName(?string $name): string
    {
        $s = trim((string) $name);
        // Strip honorific prefix (longest variants implicitly handled by alternation).
        $s = preg_replace('/^\s*(معلمة|معلمه|معلم)\s+/u', '', $s);
        // Fold orthographic variants.
        $s = str_replace(['أ', 'إ', 'آ', 'ٱ'], 'ا', $s);
        $s = str_replace('ة', 'ه', $s);
        $s = str_replace('ى', 'ي', $s);
        // Remove tashkeel/diacritics and tatweel.
        $s = preg_replace('/[\x{0617}-\x{061A}\x{064B}-\x{0652}\x{0640}]/u', '', $s);
        // Collapse whitespace.
        $s = preg_replace('/\s+/u', ' ', $s);

        return trim((string) $s);
    }

    /**
     * Memoized map of normalized student name => [student ids]. Built once per
     * service instance so the per-timetable-row resolution below doesn't reload
     * the whole students table on every call.
     *
     * @var array<string, int[]>|null
     */
    private ?array $studentNormMap = null;

    private function resolveGlobalStudentId(?string $studentName): ?int
    {
        if (empty(trim((string)$studentName))) return null;

        $cleanName = trim($studentName);

        // Only match existing students — do NOT auto-create stubs.
        // Timetable rows without a student_id must be manually mapped via the UI.

        // Tier 1 — exact raw match.
        $student = Student::where('name', $cleanName)->first();
        if ($student) return $student->id;

        // Tier 2 — exact NORMALIZED match, accepted ONLY when it maps to exactly
        // one student. Same Arabic orthographic drift (ة/ه, أإآ→ا, ى→ي) breaks the
        // exact match here too. We deliberately do NOT fall back to fuzzy/containment
        // matching for students: a wrong student means messaging the wrong guardian's
        // phone, so anything ambiguous is left for manual student_id mapping.
        $needle = $this->normalizeName($cleanName);
        if ($needle !== '') {
            $map = $this->studentNormMap();
            if (isset($map[$needle]) && count($map[$needle]) === 1) {
                return $map[$needle][0];
            }
        }

        Log::warning("LegacySync: No unambiguous student match for name '{$cleanName}' (normalized '{$needle}') — set student_id on the timetable row to fix this.");

        return null;
    }

    /**
     * @return array<string, int[]>
     */
    private function studentNormMap(): array
    {
        if ($this->studentNormMap === null) {
            $this->studentNormMap = [];
            foreach (Student::all(['id', 'name']) as $s) {
                $norm = $this->normalizeName($s->name);
                if ($norm !== '') {
                    $this->studentNormMap[$norm][] = $s->id;
                }
            }
        }

        return $this->studentNormMap;
    }
}
