<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\AdminService;
use App\Services\ApiResponseService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminController extends Controller
{
    public function __construct(
        private readonly AdminService $adminService,
        private readonly ApiResponseService $response,
    ) {}

    // ── Supervisor Management ────────────────────────────────

    public function listSupervisors(Request $request): JsonResponse
    {
        $paginator = $this->adminService->listSupervisors(
            filters: $request->only(['availability', 'search']),
            perPage: (int) $request->input('per_page', 20),
        );

        return $this->response->paginated($paginator, 'Supervisors retrieved');
    }

    public function showSupervisor(int $id): JsonResponse
    {
        $user = \App\Models\User::with(['roles', 'shifts'])->findOrFail($id);
        return $this->response->success($user);
    }

    public function getShifts(int $id): JsonResponse
    {
        $shifts = $this->adminService->getShifts($id);
        return $this->response->success($shifts, 'Shifts retrieved');
    }

    public function updateShifts(Request $request, int $id): JsonResponse
    {
        $data = $request->validate([
            'shifts'              => 'required|array|size:7',
            'shifts.*.day_of_week'=> 'required|integer|min:0|max:6',
            'shifts.*.start_time' => 'required|date_format:H:i',
            'shifts.*.end_time'   => 'required|date_format:H:i',
            'shifts.*.is_active'  => 'required|boolean',
        ]);

        $shifts = $this->adminService->updateShifts($id, $data['shifts']);
        return $this->response->success($shifts, 'Shifts updated');
    }

    public function createSupervisor(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name'             => 'required|string|max:255',
            'email'            => 'required|email|unique:users,email',
            'phone'            => 'nullable|string|max:20',
            'password'         => 'required|string|min:8',
            'max_open_tickets' => 'nullable|integer|min:1|max:100',
        ]);

        $user = $this->adminService->createSupervisor($data);

        return $this->response->success($user, 'Supervisor created', code: 201);
    }

    public function updateSupervisor(Request $request, int $id): JsonResponse
    {
        $data = $request->validate([
            'name'             => 'sometimes|string|max:255',
            'email'            => 'sometimes|email',
            'phone'            => 'nullable|string|max:20',
            'password'         => 'nullable|string|min:8',
            'max_open_tickets' => 'nullable|integer|min:1|max:100',
        ]);

        $user = $this->adminService->updateSupervisor($id, $data);

        return $this->response->success($user, 'Supervisor updated');
    }

    public function deleteSupervisor(int $id): JsonResponse
    {
        $this->adminService->deleteSupervisor($id);
        return $this->response->success(message: 'Supervisor deactivated');
    }

    // ── Analytics ──────────────────────────────────────

    public function analytics(Request $request): JsonResponse
    {
        $data = $this->adminService->analytics(
            $request->only(['from', 'to'])
        );

        return $this->response->success($data, 'Analytics retrieved');
    }

    // ── Audit Log ──────────────────────────────────────

    public function auditLog(Request $request): JsonResponse
    {
        $paginator = $this->adminService->auditLog(
            filters: $request->only(['ticket_id', 'user_id', 'action', 'from', 'to']),
            perPage: (int) $request->input('per_page', 50),
        );

        return $this->response->paginated($paginator, 'Audit log retrieved');
    }
}
