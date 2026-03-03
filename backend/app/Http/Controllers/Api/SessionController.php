<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\ApiResponseService;
use App\Services\SessionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SessionController extends Controller
{
    public function __construct(
        private readonly SessionService $sessionService,
        private readonly ApiResponseService $response,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $paginator = $this->sessionService->list(
            filters: $request->only(['date', 'from', 'to', 'status', 'teacher_id']),
            perPage: (int) $request->input('per_page', 20),
        );
        return $this->response->paginated($paginator);
    }

    public function show(int $id): JsonResponse
    {
        return $this->response->success($this->sessionService->show($id));
    }

    public function updateStatus(Request $request, int $id): JsonResponse
    {
        $data = $request->validate([
            'status' => 'required|in:scheduled,completed,cancelled',
            'cancellation_reason' => 'required_if:status,cancelled|nullable|string|max:500',
        ]);

        $session = $this->sessionService->updateStatus(
            id: $id,
            status: $data['status'],
            reason: $data['cancellation_reason'] ?? null,
        );

        return $this->response->success($session, 'Session updated');
    }
}
