<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Models\Student;
use App\Models\ScheduleEntry;
use App\Models\ClassSession;
use App\Services\ApiResponseService;
use App\Services\StudentService;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class StudentController extends CrudController
{
    public function __construct(StudentService $service, ApiResponseService $response)
    {
        parent::__construct($service, $response);
    }

    protected function storeRules(): array
    {
        return [
            'name'         => 'required|string|max:255',
            'guardian_id'  => 'nullable|exists:guardians,id',
            'phone'        => 'nullable|string|max:20',
            'student_code' => 'nullable|string|max:50',
            'notes'        => 'nullable|string|max:2000',
        ];
    }

    protected function updateRules(): array
    {
        return [
            'name'         => 'sometimes|string|max:255',
            'guardian_id'  => 'nullable|exists:guardians,id',
            'phone'        => 'nullable|string|max:20',
            'student_code' => 'nullable|string|max:50',
            'notes'        => 'nullable|string|max:2000',
        ];
    }

    // ── Per-Student Schedule Entries ─────────────────────

    public function scheduleEntries(int $id): JsonResponse
    {
        $student = Student::findOrFail($id);
        $entries = $student->scheduleEntries()->with('teacher:id,name')->get();

        return $this->response->success($entries);
    }

    public function storeScheduleEntry(Request $request, int $id): JsonResponse
    {
        $student = Student::findOrFail($id);

        $validated = $request->validate([
            'title'       => 'required|string|max:255',
            'day_of_week' => 'required|integer|min:0|max:6',
            'start_time'  => 'required|date_format:H:i',
            'end_time'    => 'required|date_format:H:i|after:start_time',
            'teacher_id'  => 'nullable|exists:teachers,id',
            'recurrence'  => 'nullable|in:weekly,biweekly,once',
            'notes'       => 'nullable|string|max:2000',
        ]);

        $entry = $student->scheduleEntries()->create($validated);
        $entry->load('teacher:id,name');

        return $this->response->success($entry, 'تم إضافة الحصة بنجاح', 201);
    }

    public function updateScheduleEntry(Request $request, int $id, int $entryId): JsonResponse
    {
        $entry = ScheduleEntry::where('student_id', $id)->findOrFail($entryId);

        $validated = $request->validate([
            'title'       => 'sometimes|string|max:255',
            'day_of_week' => 'sometimes|integer|min:0|max:6',
            'start_time'  => 'sometimes|date_format:H:i',
            'end_time'    => 'sometimes|date_format:H:i',
            'teacher_id'  => 'nullable|exists:teachers,id',
            'recurrence'  => 'nullable|in:weekly,biweekly,once',
            'notes'       => 'nullable|string|max:2000',
        ]);

        $entry->update($validated);
        $entry->load('teacher:id,name');

        return $this->response->success($entry, 'تم تحديث الحصة بنجاح');
    }

    public function destroyScheduleEntry(int $id, int $entryId): JsonResponse
    {
        $entry = ScheduleEntry::where('student_id', $id)->findOrFail($entryId);
        $entry->delete();

        return $this->response->success(null, 'تم حذف الحصة بنجاح');
    }

    // ── Class Sessions ──────────────────────────────────

    public function classSessions(Request $request, int $id): JsonResponse
    {
        $student = Student::findOrFail($id);

        $month = $request->input('month', now()->month);
        $year = $request->input('year', now()->year);

        $sessions = $student->classSessions()
            ->whereMonth('session_date', $month)
            ->whereYear('session_date', $year)
            ->with('teacher:id,name')
            ->get();

        return $this->response->success($sessions);
    }

    public function generateClassSessions(Request $request, int $id): JsonResponse
    {
        $student = Student::findOrFail($id);

        $month = (int) $request->input('month', now()->month);
        $year = (int) $request->input('year', now()->year);

        $startOfMonth = Carbon::create($year, $month, 1)->startOfDay();
        $endOfMonth = $startOfMonth->copy()->endOfMonth();

        $entries = $student->scheduleEntries()->get();
        $created = 0;

        foreach ($entries as $entry) {
            $current = $startOfMonth->copy();

            // Find first matching day of week in the month
            while ($current->dayOfWeek !== $entry->day_of_week && $current->lte($endOfMonth)) {
                $current->addDay();
            }

            // Generate sessions for each matching day
            while ($current->lte($endOfMonth)) {
                // Skip if session already exists for this date + entry
                $exists = ClassSession::where('student_id', $id)
                    ->where('schedule_entry_id', $entry->id)
                    ->where('session_date', $current->toDateString())
                    ->exists();

                if (!$exists) {
                    ClassSession::create([
                        'schedule_entry_id' => $entry->id,
                        'student_id'        => $id,
                        'teacher_id'        => $entry->teacher_id,
                        'title'             => $entry->title,
                        'session_date'      => $current->toDateString(),
                        'start_time'        => $entry->start_time,
                        'end_time'          => $entry->end_time,
                        'status'            => 'scheduled',
                    ]);
                    $created++;
                }

                // Next occurrence
                if ($entry->recurrence === 'biweekly') {
                    $current->addWeeks(2);
                } else {
                    $current->addWeek();
                }
            }
        }

        return $this->response->success(
            ['created' => $created],
            "تم إنشاء {$created} حصة للشهر {$month}/{$year}",
            201
        );
    }

    public function rescheduleSession(Request $request, int $id, int $sessionId): JsonResponse
    {
        $session = ClassSession::where('student_id', $id)->findOrFail($sessionId);

        $validated = $request->validate([
            'rescheduled_date'       => 'required|date',
            'rescheduled_start_time' => 'required|date_format:H:i',
            'rescheduled_end_time'   => 'required|date_format:H:i|after:rescheduled_start_time',
        ]);

        $session->update([
            ...$validated,
            'status' => 'rescheduled',
        ]);

        $session->load('teacher:id,name');

        return $this->response->success($session, 'تم إعادة جدولة الحصة بنجاح');
    }

    public function cancelSession(Request $request, int $id, int $sessionId): JsonResponse
    {
        $session = ClassSession::where('student_id', $id)->findOrFail($sessionId);

        $validated = $request->validate([
            'cancellation_reason' => 'nullable|string|max:500',
        ]);

        $session->update([
            'status' => 'cancelled',
            'cancellation_reason' => $validated['cancellation_reason'] ?? null,
        ]);

        return $this->response->success($session, 'تم إلغاء الحصة');
    }

    public function completeSession(int $id, int $sessionId): JsonResponse
    {
        $session = ClassSession::where('student_id', $id)->findOrFail($sessionId);

        $session->update(['status' => 'completed']);

        return $this->response->success($session, 'تم تسجيل إتمام الحصة');
    }
}
