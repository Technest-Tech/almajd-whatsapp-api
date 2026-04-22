<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\CalendarTeacher;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;
use Illuminate\Validation\ValidationException;

class CalendarTeacherController extends Controller
{
    /**
     * Display a listing of calendar teachers
     * GET /api/v1/calendar-teachers
     */
    public function index(Request $request): JsonResponse
    {
        try {
            if (!Schema::hasTable('calendar_teachers')) {
                return response()->json([]);
            }

            $teachers = CalendarTeacher::withCount(['timetables', 'exceptionalClasses'])
                ->orderBy('name')
                ->get();

            return response()->json($teachers);
        } catch (\Exception $e) {
            Log::error('Error fetching calendar teachers: ' . $e->getMessage());
            return response()->json([
                'error' => true,
                'message' => 'Failed to fetch calendar teachers: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Store a newly created calendar teacher
     * POST /api/v1/calendar-teachers
     */
    public function store(Request $request): JsonResponse
    {
        try {
            $request->validate([
                'name' => 'required|string|max:255',
                'whatsapp' => 'required|string|unique:calendar_teachers,whatsapp',
            ]);

            $teacher = CalendarTeacher::create($request->all());

            return response()->json($teacher, 201);
        } catch (ValidationException $e) {
            return response()->json([
                'error' => true,
                'message' => 'Validation error',
                'errors' => $e->errors()
            ], 422);
        } catch (\Exception $e) {
            Log::error('Error creating calendar teacher: ' . $e->getMessage());
            return response()->json([
                'error' => true,
                'message' => 'Failed to create calendar teacher'
            ], 500);
        }
    }

    /**
     * Display the specified calendar teacher
     * GET /api/v1/calendar-teachers/{id}
     */
    public function show(int $id): JsonResponse
    {
        try {
            $teacher = CalendarTeacher::with(['timetables', 'exceptionalClasses'])
                ->findOrFail($id);

            return response()->json($teacher);
        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return response()->json([
                'error' => true,
                'message' => 'Calendar teacher not found'
            ], 404);
        } catch (\Exception $e) {
            Log::error('Error fetching calendar teacher: ' . $e->getMessage());
            return response()->json([
                'error' => true,
                'message' => 'Failed to fetch calendar teacher'
            ], 500);
        }
    }

    /**
     * Update the specified calendar teacher
     * PUT /api/v1/calendar-teachers/{id}
     */
    public function update(Request $request, int $id): JsonResponse
    {
        try {
            $teacher = CalendarTeacher::findOrFail($id);

            $request->validate([
                'name' => 'sometimes|string|max:255',
                'whatsapp' => 'sometimes|string|unique:calendar_teachers,whatsapp,' . $id,
            ]);

            $teacher->update($request->all());

            return response()->json($teacher);
        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return response()->json([
                'error' => true,
                'message' => 'Calendar teacher not found'
            ], 404);
        } catch (ValidationException $e) {
            return response()->json([
                'error' => true,
                'message' => 'Validation error',
                'errors' => $e->errors()
            ], 422);
        } catch (\Exception $e) {
            Log::error('Error updating calendar teacher: ' . $e->getMessage());
            return response()->json([
                'error' => true,
                'message' => 'Failed to update calendar teacher'
            ], 500);
        }
    }

    /**
     * Remove the specified calendar teacher
     * DELETE /api/v1/calendar-teachers/{id}
     */
    public function destroy(int $id): JsonResponse
    {
        try {
            $teacher = CalendarTeacher::findOrFail($id);
            $teacher->delete();

            return response()->json(['message' => 'Calendar teacher deleted successfully']);
        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return response()->json([
                'error' => true,
                'message' => 'Calendar teacher not found'
            ], 404);
        } catch (\Exception $e) {
            Log::error('Error deleting calendar teacher: ' . $e->getMessage());
            return response()->json([
                'error' => true,
                'message' => 'Failed to delete calendar teacher'
            ], 500);
        }
    }
}
