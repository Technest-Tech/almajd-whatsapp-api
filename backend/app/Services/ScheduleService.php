<?php

declare(strict_types=1);

namespace App\Services;

use App\Console\Commands\GenerateSessionsCommand;
use App\Jobs\PropagateScheduleEntryChangesJob;
use App\Models\ClassSession;
use App\Models\Schedule;
use App\Models\ScheduleEntry;
use App\Models\Student;
use Carbon\Carbon;

class ScheduleService
{
    /**
     * List schedules with entries count + student name.
     * Optionally filter by student_id.
     */
    public function list(array $filters = [], int $perPage = 20)
    {
        $query = Schedule::with('student:id,name')
            ->withCount('entries')
            ->latest();

        if (isset($filters['student_id'])) {
            $query->where('student_id', $filters['student_id']);
        }

        if (isset($filters['is_active'])) {
            $query->where('is_active', filter_var($filters['is_active'], FILTER_VALIDATE_BOOLEAN));
        }

        if (!empty($filters['search'])) {
            $query->where(function ($q) use ($filters) {
                $q->where('name', 'like', "%{$filters['search']}%")
                  ->orWhereHas('student', fn ($sq) => $sq->where('name', 'like', "%{$filters['search']}%"));
            });
        }

        return $query->paginate($perPage);
    }

    /**
     * Get schedule with all entries, teacher details, and student name.
     */
    public function show(int $id): Schedule
    {
        return Schedule::with([
            'student:id,name,whatsapp_number',
            'entries' => fn ($q) => $q->with('teacher:id,name')->orderBy('day_of_week')->orderBy('start_time'),
        ])->findOrFail($id);
    }

    /**
     * Create a schedule (timetable template).
     * After creation, automatically generate 3 months of class sessions.
     */
    public function create(array $data): Schedule
    {
        $schedule = Schedule::create($data);

        // Auto-generate 3 months of sessions if student_id provided
        if (!empty($data['student_id'])) {
            dispatch(function () use ($data) {
                $student = Student::find($data['student_id']);
                if ($student) {
                    app(GenerateSessionsCommand::class)->generateForStudent($student, months: 3, force: false);
                }
            })->afterResponse();
        }

        return $schedule->load(['student:id,name', 'entries']);
    }

    /**
     * Update a schedule. If is_active changes to false, cancel all future sessions.
     */
    public function update(int $id, array $data): Schedule
    {
        $schedule = Schedule::findOrFail($id);
        $wasActive = $schedule->is_active;
        $schedule->update($data);

        // If deactivated, cancel all future scheduled sessions
        if ($wasActive && isset($data['is_active']) && !$data['is_active']) {
            ClassSession::whereHas('scheduleEntry', fn ($q) => $q->where('schedule_id', $id))
                ->where('session_date', '>=', Carbon::today())
                ->where('status', 'scheduled')
                ->update(['status' => 'cancelled', 'cancellation_reason' => 'تم إيقاف الجدول مؤقتاً']);
        }

        // If reactivated, regenerate sessions for 3 months
        if (!$wasActive && isset($data['is_active']) && $data['is_active'] && $schedule->student_id) {
            dispatch(function () use ($schedule) {
                $student = Student::find($schedule->student_id);
                if ($student) {
                    app(GenerateSessionsCommand::class)->generateForStudent($student, months: 3, force: false);
                }
            })->afterResponse();
        }

        return $schedule->refresh()->load(['student:id,name', 'entries.teacher:id,name']);
    }

    /**
     * Delete a schedule and cancel all its future class sessions.
     */
    public function delete(int $id): void
    {
        $schedule = Schedule::with('entries')->findOrFail($id);

        // Cancel future sessions for all entries
        $entryIds = $schedule->entries->pluck('id');
        if ($entryIds->isNotEmpty()) {
            ClassSession::whereIn('schedule_entry_id', $entryIds)
                ->where('session_date', '>=', Carbon::today())
                ->where('status', 'scheduled')
                ->update(['status' => 'cancelled', 'cancellation_reason' => 'تم حذف الجدول']);
        }

        $schedule->delete(); // entries cascade via DB or model
    }

    // ── Schedule Entries ────────────────────────────────

    /**
     * Add an entry to a schedule. Propagates to existing sessions via job.
     */
    public function addEntry(int $scheduleId, array $data): ScheduleEntry
    {
        $schedule = Schedule::findOrFail($scheduleId);
        $data['schedule_id'] = $scheduleId;
        if ($schedule->student_id) {
            $data['student_id'] = $schedule->student_id;
        }
        $entry = ScheduleEntry::create($data);

        // Generate sessions for this new entry
        if ($schedule->student_id) {
            dispatch(function () use ($schedule) {
                $student = Student::find($schedule->student_id);
                if ($student) {
                    app(GenerateSessionsCommand::class)->generateForStudent($student, months: 3, force: false);
                }
            })->afterResponse();
        }

        return $entry->load('teacher:id,name');
    }

    /**
     * Update a schedule entry — propagates changes to all future scheduled sessions.
     */
    public function updateEntry(int $entryId, array $data): ScheduleEntry
    {
        $entry = ScheduleEntry::findOrFail($entryId);
        $entry->update($data);
        $entry->refresh()->load('teacher:id,name');

        // Propagate time/title/teacher changes to future sessions
        PropagateScheduleEntryChangesJob::dispatch(
            scheduleEntryId: $entry->id,
            title:           $entry->title,
            startTime:       $entry->start_time,
            endTime:         $entry->end_time,
            teacherId:       $entry->teacher_id,
        );

        return $entry;
    }

    /**
     * Delete a schedule entry — cancels all its future sessions.
     */
    public function deleteEntry(int $entryId): void
    {
        $entry = ScheduleEntry::findOrFail($entryId);

        ClassSession::where('schedule_entry_id', $entryId)
            ->where('session_date', '>=', Carbon::today())
            ->where('status', 'scheduled')
            ->update(['status' => 'cancelled', 'cancellation_reason' => 'تم حذف الحصة من الجدول']);

        $entry->delete();
    }

    /**
     * Get class sessions for a schedule.
     */
    public function getSessions(int $scheduleId, ?int $month = null, ?int $year = null): array
    {
        $now = now();
        $query = ClassSession::whereHas('scheduleEntry', fn ($q) => $q->where('schedule_id', $scheduleId))
            ->with(['scheduleEntry:id,title,day_of_week'])
            ->orderBy('session_date')
            ->orderBy('start_time');

        if ($month || $year) {
            $query->whereMonth('session_date', $month ?? $now->month)
                  ->whereYear('session_date', $year ?? $now->year);
        }

        return $query->get()->toArray();
    }
}
