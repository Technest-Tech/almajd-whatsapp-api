<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\CalendarStudentStop;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\ValidationException;

class CalendarStudentStopController extends Controller
{
    /**
     * Display a listing of student stops
     * GET /api/v1/calendar-student-stops
     */
    public function index(Request $request): JsonResponse
    {
        try {
            $query = CalendarStudentStop::query();

            if ($request->has('student_name')) {
                $query->where('student_name', 'like', '%' . $request->student_name . '%');
            }

            if ($request->has('date_from')) {
                $query->where('date_to', '>=', $request->date_from);
            }
            if ($request->has('date_to')) {
                $query->where('date_from', '<=', $request->date_to);
            }

            $stops = $query->orderBy('date_from', 'desc')
                ->get();

            return response()->json($stops);
        } catch (\Exception $e) {
            Log::error('Error fetching student stops: ' . $e->getMessage());
            return response()->json([
                'error' => true,
                'message' => 'Failed to fetch student stops'
            ], 500);
        }
    }

    /**
     * Store a newly created student stop
     * POST /api/v1/calendar-student-stops
     */
    public function store(Request $request): JsonResponse
    {
        try {
            $request->validate([
                'student_name' => 'required|string|max:255',
                'date_from' => 'required|date',
                'date_to' => 'required|date|after_or_equal:date_from',
                'reason' => 'nullable|string',
            ]);

            $stop = CalendarStudentStop::create($request->all());

            return response()->json($stop, 201);
        } catch (ValidationException $e) {
            return response()->json([
                'error' => true,
                'message' => 'Validation error',
                'errors' => $e->errors()
            ], 422);
        } catch (\Exception $e) {
            Log::error('Error creating student stop: ' . $e->getMessage());
            return response()->json([
                'error' => true,
                'message' => 'Failed to create student stop'
            ], 500);
        }
    }

    /**
     * Display the specified student stop
     * GET /api/v1/calendar-student-stops/{id}
     */
    public function show(int $id): JsonResponse
    {
        try {
            $stop = CalendarStudentStop::findOrFail($id);

            return response()->json($stop);
        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return response()->json([
                'error' => true,
                'message' => 'Student stop not found'
            ], 404);
        } catch (\Exception $e) {
            Log::error('Error fetching student stop: ' . $e->getMessage());
            return response()->json([
                'error' => true,
                'message' => 'Failed to fetch student stop'
            ], 500);
        }
    }

    /**
     * Update the specified student stop
     * PUT /api/v1/calendar-student-stops/{id}
     */
    public function update(Request $request, int $id): JsonResponse
    {
        try {
            $stop = CalendarStudentStop::findOrFail($id);

            $request->validate([
                'student_name' => 'sometimes|string|max:255',
                'date_from' => 'sometimes|date',
                'date_to' => 'sometimes|date|after_or_equal:date_from',
                'reason' => 'nullable|string',
            ]);

            $stop->update($request->all());

            return response()->json($stop);
        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return response()->json([
                'error' => true,
                'message' => 'Student stop not found'
            ], 404);
        } catch (ValidationException $e) {
            return response()->json([
                'error' => true,
                'message' => 'Validation error',
                'errors' => $e->errors()
            ], 422);
        } catch (\Exception $e) {
            Log::error('Error updating student stop: ' . $e->getMessage());
            return response()->json([
                'error' => true,
                'message' => 'Failed to update student stop'
            ], 500);
        }
    }

    /**
     * Remove the specified student stop
     * DELETE /api/v1/calendar-student-stops/{id}
     */
    public function destroy(int $id): JsonResponse
    {
        try {
            $stop = CalendarStudentStop::findOrFail($id);
            $stop->delete();

            return response()->json(['message' => 'Student stop deleted successfully']);
        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return response()->json([
                'error' => true,
                'message' => 'Student stop not found'
            ], 404);
        } catch (\Exception $e) {
            Log::error('Error deleting student stop: ' . $e->getMessage());
            return response()->json([
                'error' => true,
                'message' => 'Failed to delete student stop'
            ], 500);
        }
    }
}
