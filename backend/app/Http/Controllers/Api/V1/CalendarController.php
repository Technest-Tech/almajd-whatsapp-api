<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\CalendarExceptionalClass;
use App\Models\CalendarStudentStop;
use App\Models\CalendarTeacher;
use App\Models\CalendarTeacherTimetable;
use App\Services\WhatsApp\WhatsAppServiceInterface;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;
use Illuminate\Validation\ValidationException;

class CalendarController extends Controller
{
    protected $whatsAppService;

    public function __construct(WhatsAppServiceInterface $whatsAppService)
    {
        $this->whatsAppService = $whatsAppService;
    }

    /**
     * Get calendar events
     * GET /api/v1/calendar/events
     */
    public function getEvents(Request $request): JsonResponse
    {
        try {
            if (!Schema::hasTable('calendar_teacher_timetables')) {
                return response()->json(['events' => []], 200, [
                    'Content-Type' => 'application/json; charset=utf-8'
                ]);
            }

            $request->validate([
                'from_date' => 'nullable|date',
                'to_date' => 'nullable|date',
                'teacher_id' => 'nullable|integer',
                'day' => 'nullable|string|in:Sunday,Monday,Tuesday,Wednesday,Thursday,Friday,Saturday',
            ]);

            $query = CalendarTeacherTimetable::with(['teacher' => function ($q) {
                $q->select('id', 'name');
            }])
                ->where('status', 'active');

            if ($request->has('teacher_id')) {
                $query->where('teacher_id', $request->teacher_id);
            }

            if ($request->has('day')) {
                $query->where('day', $request->day);
            }

            $fromDate = $request->has('from_date') ? $request->input('from_date') : null;
            $toDate = $request->has('to_date') ? $request->input('to_date') : null;

            $today = date('Y-m-d');
            $timetables = $query->where(function ($q) use ($today) {
                $q->whereNull('deleted_date')
                    ->orWhere('deleted_date', '!=', $today);
            })
                ->orderBy('start_time')
                ->get();

            $events = $timetables->map(function ($timetable) {
                try {
                    $day = $timetable->day ?? 'Sunday';
                    $dayOfWeek = $this->dayOfWeekToInt($day);
                    $teacher = $timetable->teacher;

                    return [
                        'id' => $timetable->id ?? 0,
                        'title' => $timetable->student_name ?? '',
                        'daysOfWeek' => [$dayOfWeek],
                        'startTime' => $timetable->start_time ?? '00:00:00',
                        'endTime' => $timetable->finish_time ?? null,
                        'extendedProps' => [
                            'studentName' => $timetable->student_name ?? '',
                            'country' => $timetable->country ?? 'canada',
                            'teacherId' => $timetable->teacher_id ?? 0,
                            'teacherName' => ($teacher && isset($teacher->name)) ? $teacher->name : '',
                            'day' => $day,
                            'type' => 'recurring',
                        ],
                    ];
                } catch (\Exception $e) {
                    Log::error('Error mapping timetable to event: ' . $e->getMessage());
                    return null;
                }
            })->filter();

            // Fetch exceptional classes
            $exceptionalQuery = CalendarExceptionalClass::with(['teacher' => function ($q) {
                $q->select('id', 'name');
            }]);

            if ($request->has('teacher_id')) {
                $exceptionalQuery->where('teacher_id', $request->teacher_id);
            }

            if ($fromDate && $toDate) {
                $exceptionalQuery->whereBetween('date', [$fromDate, $toDate]);
            } elseif ($fromDate) {
                $exceptionalQuery->where('date', '>=', $fromDate);
            } elseif ($toDate) {
                $exceptionalQuery->where('date', '<=', $toDate);
            } else {
                $defaultFromDate = Carbon::now()->subDays(30)->format('Y-m-d');
                $defaultToDate = Carbon::now()->addDays(365)->format('Y-m-d');
                $exceptionalQuery->whereBetween('date', [$defaultFromDate, $defaultToDate]);
            }

            $exceptionalClasses = $exceptionalQuery->orderBy('date')
                ->orderBy('time')
                ->get();

            $exceptionalEvents = $exceptionalClasses->map(function ($exceptionalClass) {
                try {
                    $date = Carbon::parse($exceptionalClass->date);
                    $dayOfWeek = $date->dayOfWeek;
                    $teacher = $exceptionalClass->teacher;

                    return [
                        'id' => 'exceptional_' . $exceptionalClass->id,
                        'title' => $exceptionalClass->student_name ?? '',
                        'daysOfWeek' => [$dayOfWeek],
                        'startTime' => $exceptionalClass->time ?? '00:00:00',
                        'endTime' => null,
                        'start' => $exceptionalClass->date->format('Y-m-d'),
                        'extendedProps' => [
                            'studentName' => $exceptionalClass->student_name ?? '',
                            'country' => 'canada',
                            'teacherId' => $exceptionalClass->teacher_id ?? 0,
                            'teacherName' => ($teacher && isset($teacher->name)) ? $teacher->name : '',
                            'day' => $date->format('l'),
                            'type' => 'exceptional',
                            'exceptionalClassId' => $exceptionalClass->id,
                            'date' => $exceptionalClass->date->format('Y-m-d'),
                        ],
                    ];
                } catch (\Exception $e) {
                    Log::error('Error mapping exceptional class to event: ' . $e->getMessage());
                    return null;
                }
            })->filter();

            $allEvents = $events->merge($exceptionalEvents)->values();

            return response()->json(['events' => $allEvents], 200, [
                'Content-Type' => 'application/json; charset=utf-8'
            ]);
        } catch (ValidationException $e) {
            return response()->json([
                'error' => true,
                'message' => 'Validation error',
                'errors' => $e->errors()
            ], 422);
        } catch (\Exception $e) {
            Log::error('Error fetching calendar events: ' . $e->getMessage());
            return response()->json([
                'error' => true,
                'message' => 'An error occurred while fetching calendar events: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Generate daily reminder
     * GET /api/v1/calendar/reminders/daily
     */
    public function generateDailyReminder(Request $request): JsonResponse
    {
        try {
            $request->validate([
                'start_time' => 'required|string',
                'end_time' => 'required|string',
                'day' => 'required|string|in:Sunday,Monday,Tuesday,Wednesday,Thursday,Friday,Saturday'
            ]);

            $startTime = $request->input('start_time');
            $endTime = $request->input('end_time');
            $day = $request->input('day');
            $today = date('Y-m-d');

            $date = Carbon::now();
            $dayNames = ['Sunday' => 0, 'Monday' => 1, 'Tuesday' => 2, 'Wednesday' => 3, 'Thursday' => 4, 'Friday' => 5, 'Saturday' => 6];
            $targetDay = $dayNames[$day] ?? 0;

            if ($date->dayOfWeek != $targetDay) {
                $daysUntilTarget = ($targetDay - $date->dayOfWeek + 7) % 7;
                if ($daysUntilTarget == 0) {
                    $daysUntilTarget = 7;
                }
                $date->addDays($daysUntilTarget);
            }
            $dateString = $date->format('Y-m-d');

            // Get students who have active stop periods on this date
            $stoppedStudents = CalendarStudentStop::where('date_from', '<=', $dateString)
                ->where('date_to', '>=', $dateString)
                ->pluck('student_name')
                ->toArray();

            $data = CalendarTeacherTimetable::whereBetween('start_time', [$startTime, $endTime])
                ->where('day', $day)
                ->where('status', 'active')
                ->where(function ($query) use ($today) {
                    $query->whereNull('deleted_date')
                        ->orWhere('deleted_date', '!=', $today);
                })
                ->whereNotIn('student_name', $stoppedStudents)
                ->orderBy('start_time')
                ->get();

            $groupedData = $data->groupBy(['start_time', 'teacher_id']);

            $arabicDays = [
                'Sunday' => 'الأحد', 'Monday' => 'الاثنين', 'Tuesday' => 'الثلاثاء',
                'Wednesday' => 'الأربعاء', 'Thursday' => 'الخميس', 'Friday' => 'الجمعة', 'Saturday' => 'السبت'
            ];

            $arabicMonths = [
                1 => 'يناير', 2 => 'فبراير', 3 => 'مارس', 4 => 'أبريل',
                5 => 'مايو', 6 => 'يونيو', 7 => 'يوليو', 8 => 'أغسطس',
                9 => 'سبتمبر', 10 => 'أكتوبر', 11 => 'نوفمبر', 12 => 'ديسمبر'
            ];

            $formattedDate = $arabicDays[$day] . '، ' . $date->format('d') . ' ' . $arabicMonths[$date->format('n')] . ' ' . $date->format('Y');
            $message = "";

            foreach ($groupedData as $timeSlot => $appointmentsByTime) {
                $formattedTime = Carbon::parse($timeSlot)->format('g:i');
                $message .= "(" . $formattedTime . ")\n";

                $teacherLines = [];
                foreach ($appointmentsByTime as $teacherId => $appointments) {
                    $teacher = CalendarTeacher::find($teacherId);
                    $studentNames = [];
                    foreach ($appointments as $appointment) {
                        $studentNames[] = $appointment->student_name;
                    }
                    $teacherLines[] = "[" . ($teacher->name ?? '') . "]," . implode(",", $studentNames);
                }

                $message .= implode("\n", $teacherLines) . "\n";
                $message .= "------------------------\n";
            }

            // Get exceptional classes for the date
            $exceptionalClasses = $this->getExceptionalClasses($dateString, $stoppedStudents);
            if (!empty($exceptionalClasses)) {
                $message .= "\n" . $exceptionalClasses;
            }

            return response()->json(['message' => $message], 200, [
                'Content-Type' => 'application/json; charset=utf-8'
            ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        } catch (ValidationException $e) {
            return response()->json([
                'error' => true,
                'message' => 'Validation error: ' . implode(', ', $e->errors())
            ], 422);
        } catch (\Exception $e) {
            Log::error('Error generating daily reminder: ' . $e->getMessage());
            return response()->json([
                'error' => true,
                'message' => 'An error occurred while generating reminder: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Get exceptional classes reminder
     * GET /api/v1/calendar/reminders/exceptional
     */
    public function getExceptionalReminders(Request $request): JsonResponse
    {
        try {
            $request->validate([
                'date' => 'required|date'
            ]);

            $date = $request->input('date');
            $stoppedStudents = CalendarStudentStop::where('date_from', '<=', $date)
                ->where('date_to', '>=', $date)
                ->pluck('student_name')
                ->toArray();

            $exceptionalClasses = $this->getExceptionalClasses($date, $stoppedStudents);

            return response()->json(['message' => $exceptionalClasses], 200, [
                'Content-Type' => 'application/json; charset=utf-8'
            ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        } catch (ValidationException $e) {
            return response()->json([
                'error' => true,
                'message' => 'Validation error: ' . implode(', ', $e->errors())
            ], 422);
        } catch (\Exception $e) {
            Log::error('Error getting exceptional reminders: ' . $e->getMessage());
            return response()->json([
                'error' => true,
                'message' => 'An error occurred while getting exceptional reminders'
            ], 500);
        }
    }

    /**
     * Create teacher timetable entry
     * POST /api/v1/calendar/teacher-timetable
     */
    public function storeTeacherTimetable(Request $request): JsonResponse
    {
        try {
            $request->validate([
                'teacher_id' => 'required|integer|exists:calendar_teachers,id',
                'day' => 'required|string|in:Sunday,Monday,Tuesday,Wednesday,Thursday,Friday,Saturday',
                'start_time' => 'required|string',
                'finish_time' => 'nullable|string',
                'student_name' => 'required|string',
                'country' => 'required|string|in:canada,uk,eg',
                'status' => 'nullable|string|in:active,inactive',
                'reactive_date' => 'nullable|date',
                'deleted_date' => 'nullable|date',
            ]);

            $timetable = CalendarTeacherTimetable::create($request->all());

            return response()->json($timetable->load('teacher'), 201);
        } catch (ValidationException $e) {
            return response()->json([
                'error' => true,
                'message' => 'Validation error',
                'errors' => $e->errors()
            ], 422);
        } catch (\Exception $e) {
            Log::error('Error creating teacher timetable: ' . $e->getMessage());
            return response()->json([
                'error' => true,
                'message' => 'Failed to create teacher timetable'
            ], 500);
        }
    }

    /**
     * Update teacher timetable entry
     * PUT /api/v1/calendar/teacher-timetable/{id}
     */
    public function updateTeacherTimetable(Request $request, int $id): JsonResponse
    {
        try {
            $timetable = CalendarTeacherTimetable::findOrFail($id);

            $request->validate([
                'teacher_id' => 'sometimes|integer|exists:calendar_teachers,id',
                'day' => 'sometimes|string|in:Sunday,Monday,Tuesday,Wednesday,Thursday,Friday,Saturday',
                'start_time' => 'sometimes|string',
                'finish_time' => 'nullable|string',
                'student_name' => 'sometimes|string',
                'country' => 'sometimes|string|in:canada,uk,eg',
                'status' => 'sometimes|string|in:active,inactive',
                'reactive_date' => 'nullable|date',
                'deleted_date' => 'nullable|date',
            ]);

            $timetable->update($request->all());

            return response()->json($timetable->load('teacher'));
        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return response()->json([
                'error' => true,
                'message' => 'Timetable not found'
            ], 404);
        } catch (ValidationException $e) {
            return response()->json([
                'error' => true,
                'message' => 'Validation error',
                'errors' => $e->errors()
            ], 422);
        } catch (\Exception $e) {
            Log::error('Error updating teacher timetable: ' . $e->getMessage());
            return response()->json([
                'error' => true,
                'message' => 'Failed to update teacher timetable'
            ], 500);
        }
    }

    /**
     * Delete teacher timetable entry
     * DELETE /api/v1/calendar/teacher-timetable/{id}
     */
    public function deleteTeacherTimetable(int $id): JsonResponse
    {
        try {
            $timetable = CalendarTeacherTimetable::findOrFail($id);
            $timetable->delete();

            return response()->json(['message' => 'Timetable deleted successfully']);
        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return response()->json([
                'error' => true,
                'message' => 'Timetable not found'
            ], 404);
        } catch (\Exception $e) {
            Log::error('Error deleting teacher timetable: ' . $e->getMessage());
            return response()->json([
                'error' => true,
                'message' => 'Failed to delete teacher timetable'
            ], 500);
        }
    }

    /**
     * Create exceptional class
     * POST /api/v1/calendar/exceptional-class
     */
    public function storeExceptionalClass(Request $request): JsonResponse
    {
        try {
            $request->validate([
                'student_name' => 'required|string',
                'date' => 'required|date',
                'time' => 'required|string',
                'teacher_id' => 'required|integer|exists:calendar_teachers,id',
            ]);

            $exceptionalClass = CalendarExceptionalClass::create($request->all());

            return response()->json($exceptionalClass->load('teacher'), 201);
        } catch (ValidationException $e) {
            return response()->json([
                'error' => true,
                'message' => 'Validation error',
                'errors' => $e->errors()
            ], 422);
        } catch (\Exception $e) {
            Log::error('Error creating exceptional class: ' . $e->getMessage());
            return response()->json([
                'error' => true,
                'message' => 'Failed to create exceptional class'
            ], 500);
        }
    }

    /**
     * Delete exceptional class
     * DELETE /api/v1/calendar/exceptional-class/{id}
     */
    public function deleteExceptionalClass(int $id): JsonResponse
    {
        try {
            $exceptionalClass = CalendarExceptionalClass::findOrFail($id);
            $exceptionalClass->delete();

            return response()->json(['message' => 'Exceptional class deleted successfully']);
        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return response()->json([
                'error' => true,
                'message' => 'Exceptional class not found'
            ], 404);
        } catch (\Exception $e) {
            Log::error('Error deleting exceptional class: ' . $e->getMessage());
            return response()->json([
                'error' => true,
                'message' => 'Failed to delete exceptional class'
            ], 500);
        }
    }

    /**
     * Get exceptional classes for a student
     * GET /api/v1/calendar/exceptional-classes/student
     */
    public function getStudentExceptionalClasses(Request $request): JsonResponse
    {
        try {
            $request->validate([
                'student_name' => 'required|string',
            ]);

            $studentName = $request->input('student_name');

            $exceptionalClasses = CalendarExceptionalClass::where('student_name', $studentName)
                ->with('teacher:id,name')
                ->orderBy('date', 'desc')
                ->orderBy('time', 'asc')
                ->get();

            return response()->json([
                'exceptional_classes' => $exceptionalClasses->map(function ($class) {
                    return [
                        'id' => $class->id,
                        'student_name' => $class->student_name,
                        'date' => $class->date->format('Y-m-d'),
                        'time' => $class->time,
                        'teacher_id' => $class->teacher_id,
                        'teacher' => $class->teacher ? [
                            'id' => $class->teacher->id,
                            'name' => $class->teacher->name,
                        ] : null,
                        'created_at' => $class->created_at->toIso8601String(),
                        'updated_at' => $class->updated_at->toIso8601String(),
                    ];
                })
            ], 200, [
                'Content-Type' => 'application/json; charset=utf-8'
            ]);
        } catch (\Exception $e) {
            Log::error('Error getting student exceptional classes: ' . $e->getMessage());
            return response()->json([
                'error' => true,
                'message' => 'Failed to get exceptional classes'
            ], 500);
        }
    }

    /**
     * Get teacher timetable WhatsApp message
     * GET /api/v1/calendar/teacher/{id}/whatsapp
     */
    public function getTeacherTimetableWhatsApp(int $id): JsonResponse
    {
        try {
            $teacher = CalendarTeacher::findOrFail($id);
            $timeTable = CalendarTeacherTimetable::where('teacher_id', $id)
                ->where('status', 'active')
                ->orderByRaw("FIELD(day, 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday')")
                ->orderBy('start_time')
                ->get();

            $groupedTimeTable = $timeTable->groupBy('day');

            $daysOrder = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
            $groupedTimeTable = $groupedTimeTable->sortBy(function ($value, $key) use ($daysOrder) {
                return array_search($key, $daysOrder);
            });

            $message = "📅 *Teacher Timetable*\n";
            $message .= "━━━━━━━━━━━━━━━━━━━━\n\n";
            $message .= "👨‍🏫 *Teacher:* {$teacher->name}\n";
            $message .= "━━━━━━━━━━━━━━━━━━━━\n\n";

            $daysInArabic = [
                'Sunday' => 'الأحد', 'Monday' => 'الاثنين', 'Tuesday' => 'الثلاثاء',
                'Wednesday' => 'الأربعاء', 'Thursday' => 'الخميس', 'Friday' => 'الجمعة', 'Saturday' => 'السبت',
            ];

            $totalLessons = 0;

            foreach ($groupedTimeTable as $day => $entries) {
                $dayInArabic = $daysInArabic[$day] ?? $day;
                $message .= "📆 *{$dayInArabic}*\n";
                $message .= "─────────────────────\n";

                foreach ($entries as $entry) {
                    $startTime = Carbon::parse($entry->start_time)->format('g:i A');
                    $endTime = $entry->finish_time
                        ? Carbon::parse($entry->finish_time)->format('g:i A')
                        : '';
                    $timeRange = $endTime ? "$startTime - $endTime" : $startTime;
                    $country = match ($entry->country ?? '') {
                        'uk' => '🇬🇧',
                        'eg' => '🇪🇬',
                        default => '🇨🇦',
                    };
                    $message .= "   👤 {$entry->student_name} $country [$timeRange]\n";
                    $totalLessons++;
                }

                if ($day !== $groupedTimeTable->keys()->last()) {
                    $message .= "\n━━━━━━━━━━━━━━━━━━━━\n\n";
                }
            }

            $message .= "\n━━━━━━━━━━━━━━━━━━━━\n";
            $message .= "📋 *Total Sessions: {$totalLessons}*\n\n";
            $message .= "✅ *Timetable Generated Successfully*\n";
            $message .= "📱 Almajd Academy";

            $report = urlencode($message);
            $phoneNumber = $teacher->whatsapp;

            return response()->json([
                'report' => $report,
                'phoneNumber' => $phoneNumber
            ], 200, [
                'Content-Type' => 'application/json; charset=utf-8'
            ]);
        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return response()->json([
                'error' => true,
                'message' => 'Teacher not found'
            ], 404);
        } catch (\Exception $e) {
            Log::error('Error getting teacher timetable WhatsApp: ' . $e->getMessage());
            return response()->json([
                'error' => true,
                'message' => 'Failed to get teacher timetable WhatsApp'
            ], 500);
        }
    }

    /**
     * Send teacher timetable via WhatsApp integration
     * POST /api/v1/calendar/teacher/{id}/send-whatsapp
     */
    public function sendTeacherTimetableWhatsApp(int $id): JsonResponse
    {
        try {
            $teacher = CalendarTeacher::findOrFail($id);
            $timeTable = CalendarTeacherTimetable::where('teacher_id', $id)
                ->where('status', 'active')
                ->orderByRaw("FIELD(day, 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday')")
                ->orderBy('start_time')
                ->get();

            $phoneNumber = $teacher->whatsapp;

            if (!$phoneNumber || empty(trim($phoneNumber))) {
                return response()->json([
                    'error' => true,
                    'message' => 'Teacher does not have a WhatsApp number'
                ], 400);
            }

            $groupedTimeTable = $timeTable->groupBy('day');
            $daysOrder = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
            $groupedTimeTable = $groupedTimeTable->sortBy(function ($value, $key) use ($daysOrder) {
                return array_search($key, $daysOrder);
            });

            $message = "🎓 *Almajd Academy*\n";
            $message .= "━━━━━━━━━━━━━━━━━━\n\n";
            $message .= "📋 *" . $teacher->name . " - جدول الحصص*\n\n";

            $daysInArabic = [
                'Sunday' => 'الأحد', 'Monday' => 'الاثنين', 'Tuesday' => 'الثلاثاء',
                'Wednesday' => 'الأربعاء', 'Thursday' => 'الخميس', 'Friday' => 'الجمعة', 'Saturday' => 'السبت',
            ];

            $totalLessons = 0;

            foreach ($groupedTimeTable as $day => $entries) {
                $dayInArabic = $daysInArabic[$day] ?? $day;
                $message .= "*" . $dayInArabic . "*\n";

                foreach ($entries as $entry) {
                    $startTime = Carbon::parse($entry->start_time)->format('h:i A');
                    $endTime = $entry->finish_time
                        ? Carbon::parse($entry->finish_time)->format('h:i A')
                        : '';
                    $timeRange = $endTime ? "$startTime - $endTime" : $startTime;
                    $country = match ($entry->country ?? '') {
                        'uk' => '🇬🇧',
                        'eg' => '🇪🇬',
                        default => '🇨🇦',
                    };
                    $message .= "  • " . $entry->student_name . " $country [$timeRange]\n";
                    $totalLessons++;
                }

                $message .= "\n";
            }

            $message .= "━━━━━━━━━━━━━━━━━━\n";
            $message .= "📊 *إجمالي الحصص:* " . $totalLessons . "\n\n";
            $message .= "_جدول محدث بتاريخ " . Carbon::now()->format('Y-m-d') . "_\n\n";
            $message .= "Thank you for choosing Almajd Academy! 🌟";

            $result = $this->whatsAppService->sendText($phoneNumber, $message);

            return response()->json([
                'success' => true,
                'message' => 'WhatsApp message sent successfully',
            ]);
        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return response()->json([
                'error' => true,
                'message' => 'Teacher not found'
            ], 404);
        } catch (\Exception $e) {
            Log::error('Error sending teacher timetable WhatsApp: ' . $e->getMessage());
            return response()->json([
                'error' => true,
                'message' => 'Failed to send teacher timetable WhatsApp: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Get students for a teacher
     * GET /api/v1/calendar/teacher/{id}/students
     */
    public function getTeacherStudents(int $id): JsonResponse
    {
        try {
            $teacher = CalendarTeacher::findOrFail($id);
            $today = date('Y-m-d');

            $timetables = CalendarTeacherTimetable::where('teacher_id', $id)
                ->where('status', 'active')
                ->where(function ($q) use ($today) {
                    $q->whereNull('deleted_date')
                        ->orWhere('deleted_date', '!=', $today);
                })
                ->select('student_name', 'country', 'status', 'reactive_date')
                ->distinct()
                ->get();

            $students = [];
            foreach ($timetables as $timetable) {
                $studentName = $timetable->student_name;
                if (!isset($students[$studentName])) {
                    $students[$studentName] = [
                        'student_name' => $studentName,
                        'country' => $timetable->country ?? 'canada',
                        'status' => $timetable->status ?? 'active',
                        'reactive_date' => $timetable->reactive_date ? $timetable->reactive_date->format('Y-m-d') : null,
                    ];
                }
            }

            return response()->json([
                'students' => array_values($students)
            ], 200, [
                'Content-Type' => 'application/json; charset=utf-8'
            ]);
        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return response()->json([
                'error' => true,
                'message' => 'Teacher not found'
            ], 404);
        } catch (\Exception $e) {
            Log::error('Error getting teacher students: ' . $e->getMessage());
            return response()->json([
                'error' => true,
                'message' => 'Failed to get teacher students'
            ], 500);
        }
    }

    /**
     * Update student status
     * PUT /api/v1/calendar/student/status
     */
    public function updateStudentStatus(Request $request): JsonResponse
    {
        try {
            $request->validate([
                'student_name' => 'required|string',
                'status' => 'required|string|in:active,inactive',
                'reactive_date' => 'nullable|date',
            ]);

            $studentName = $request->input('student_name');
            $status = $request->input('status');
            $reactiveDate = $request->has('reactive_date') && $request->input('reactive_date')
                ? Carbon::parse($request->input('reactive_date'))->format('Y-m-d')
                : null;

            $updated = CalendarTeacherTimetable::where('student_name', $studentName)
                ->update([
                    'status' => $status,
                    'reactive_date' => $reactiveDate,
                ]);

            return response()->json([
                'message' => 'Student status updated successfully',
                'updated_count' => $updated
            ], 200, [
                'Content-Type' => 'application/json; charset=utf-8'
            ]);
        } catch (ValidationException $e) {
            return response()->json([
                'error' => true,
                'message' => 'Validation error',
                'errors' => $e->errors()
            ], 422);
        } catch (\Exception $e) {
            Log::error('Error updating student status: ' . $e->getMessage());
            return response()->json([
                'error' => true,
                'message' => 'Failed to update student status'
            ], 500);
        }
    }

    /**
     * Get list of all students (for dropdowns)
     * GET /api/v1/calendar/students/list
     */
    public function getStudentsList(): JsonResponse
    {
        try {
            $today = date('Y-m-d');

            $students = CalendarTeacherTimetable::where('status', 'active')
                ->where(function ($q) use ($today) {
                    $q->whereNull('deleted_date')
                        ->orWhere('deleted_date', '!=', $today);
                })
                ->select('student_name')
                ->distinct()
                ->orderBy('student_name')
                ->pluck('student_name')
                ->toArray();

            return response()->json([
                'students' => $students
            ], 200, [
                'Content-Type' => 'application/json; charset=utf-8'
            ]);
        } catch (\Exception $e) {
            Log::error('Error getting students list: ' . $e->getMessage());
            return response()->json([
                'error' => true,
                'message' => 'Failed to get students list'
            ], 500);
        }
    }

    /**
     * Helper method to get exceptional classes
     */
    private function getExceptionalClasses(string $date, array $stoppedStudents = []): string
    {
        $data = CalendarExceptionalClass::where('date', $date)
            ->whereNotIn('student_name', $stoppedStudents)
            ->orderBy('time')
            ->get();

        if ($data->isEmpty()) {
            return '';
        }

        $groupedData = $data->groupBy(['time', 'teacher_id']);
        $message = '';

        foreach ($groupedData as $time => $appointmentsByTime) {
            $formattedTime = Carbon::parse($time)->format('g:i');
            $message .= "(" . $formattedTime . ")\n";

            $teacherLines = [];
            foreach ($appointmentsByTime as $teacherId => $appointments) {
                $teacher = CalendarTeacher::find($teacherId);
                $studentNames = [];
                foreach ($appointments as $appointment) {
                    $studentNames[] = $appointment->student_name;
                }
                $teacherLines[] = "[" . ($teacher->name ?? '') . "]," . implode(",", $studentNames);
            }

            $message .= implode("\n", $teacherLines) . "\n";
            $message .= "------------------------\n";
        }

        return $message;
    }

    /**
     * Helper method to convert day name to integer
     */
    private function dayOfWeekToInt(string $dayOfWeek): int
    {
        $days = [
            'Sunday' => 0, 'Monday' => 1, 'Tuesday' => 2, 'Wednesday' => 3,
            'Thursday' => 4, 'Friday' => 5, 'Saturday' => 6,
        ];
        return $days[$dayOfWeek] ?? 0;
    }
}
