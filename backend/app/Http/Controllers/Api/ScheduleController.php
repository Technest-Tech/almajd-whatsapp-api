<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\ApiResponseService;
use App\Services\ScheduleService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ScheduleController extends Controller
{
    public function __construct(
        private readonly ScheduleService $scheduleService,
        private readonly ApiResponseService $response,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $paginator = $this->scheduleService->list(
            filters: $request->only(['is_active', 'search']),
            perPage: (int) $request->input('per_page', 20),
        );
        return $this->response->paginated($paginator);
    }

    public function show(int $id): JsonResponse
    {
        return $this->response->success($this->scheduleService->show($id));
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name'        => 'required|string|max:255',
            'description' => 'nullable|string|max:2000',
            'start_date'  => 'required|date',
            'end_date'    => 'required|date|after_or_equal:start_date',
            'is_active'   => 'boolean',
        ]);
        return $this->response->success($this->scheduleService->create($data), 'Created', code: 201);
    }

    public function update(Request $request, int $id): JsonResponse
    {
        $data = $request->validate([
            'name'        => 'sometimes|string|max:255',
            'description' => 'nullable|string|max:2000',
            'start_date'  => 'sometimes|date',
            'end_date'    => 'sometimes|date',
            'is_active'   => 'boolean',
        ]);
        return $this->response->success($this->scheduleService->update($id, $data), 'Updated');
    }

    public function destroy(int $id): JsonResponse
    {
        $this->scheduleService->delete($id);
        return $this->response->success(message: 'Deleted');
    }

    // ── Schedule Entries ────────────────────────────────

    public function addEntry(Request $request, int $scheduleId): JsonResponse
    {
        $data = $request->validate([
            'teacher_id'  => 'nullable|exists:teachers,id',
            'title'       => 'required|string|max:255',
            'day_of_week' => 'required|integer|min:0|max:6',
            'start_time'  => 'required|date_format:H:i',
            'end_time'    => 'required|date_format:H:i|after:start_time',
            'recurrence'  => 'in:weekly,biweekly,once',
            'notes'       => 'nullable|string|max:2000',
        ]);
        return $this->response->success($this->scheduleService->addEntry($scheduleId, $data), 'Entry added', code: 201);
    }

    public function updateEntry(Request $request, int $scheduleId, int $entryId): JsonResponse
    {
        $data = $request->validate([
            'teacher_id'  => 'nullable|exists:teachers,id',
            'title'       => 'sometimes|string|max:255',
            'day_of_week' => 'sometimes|integer|min:0|max:6',
            'start_time'  => 'sometimes|date_format:H:i',
            'end_time'    => 'sometimes|date_format:H:i',
            'recurrence'  => 'in:weekly,biweekly,once',
            'notes'       => 'nullable|string|max:2000',
        ]);
        return $this->response->success($this->scheduleService->updateEntry($entryId, $data), 'Entry updated');
    }

    public function deleteEntry(int $scheduleId, int $entryId): JsonResponse
    {
        $this->scheduleService->deleteEntry($entryId);
        return $this->response->success(message: 'Entry deleted');
    }
}
