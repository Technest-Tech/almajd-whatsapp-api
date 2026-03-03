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

    // ── User Management ────────────────────────────────

    public function listUsers(Request $request): JsonResponse
    {
        $paginator = $this->adminService->listUsers(
            filters: $request->only(['role', 'availability', 'search']),
            perPage: (int) $request->input('per_page', 20),
        );

        return $this->response->paginated($paginator, 'Users retrieved');
    }

    public function showUser(int $id): JsonResponse
    {
        $user = \App\Models\User::with('roles')->findOrFail($id);
        return $this->response->success($user);
    }

    public function createUser(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name'             => 'required|string|max:255',
            'email'            => 'required|email|unique:users,email',
            'phone'            => 'nullable|string|max:20',
            'password'         => 'required|string|min:8',
            'role'             => 'required|in:supervisor,senior_supervisor,admin',
            'max_open_tickets' => 'nullable|integer|min:1|max:100',
        ]);

        $user = $this->adminService->createUser($data);

        return $this->response->success($user, 'User created', code: 201);
    }

    public function updateUser(Request $request, int $id): JsonResponse
    {
        $data = $request->validate([
            'name'             => 'sometimes|string|max:255',
            'email'            => 'sometimes|email',
            'phone'            => 'nullable|string|max:20',
            'password'         => 'nullable|string|min:8',
            'role'             => 'nullable|in:supervisor,senior_supervisor,admin',
            'max_open_tickets' => 'nullable|integer|min:1|max:100',
        ]);

        $user = $this->adminService->updateUser($id, $data);

        return $this->response->success($user, 'User updated');
    }

    public function deleteUser(int $id): JsonResponse
    {
        $this->adminService->deleteUser($id);
        return $this->response->success(message: 'User deactivated');
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
