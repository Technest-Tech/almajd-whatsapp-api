<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Enums\UserAvailability;
use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\LoginRequest;
use App\Http\Requests\Auth\RefreshRequest;
use App\Http\Requests\Auth\UpdateAvailabilityRequest;
use App\Services\ApiResponseService;
use App\Services\Auth\AuthService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AuthController extends Controller
{
    public function __construct(
        private readonly AuthService $authService,
        private readonly ApiResponseService $response,
    ) {}

    /**
     * POST /api/auth/login
     */
    public function login(LoginRequest $request): JsonResponse
    {
        try {
            $result = $this->authService->login(
                email: $request->validated('email'),
                password: $request->validated('password'),
                deviceId: $request->validated('device_id'),
                deviceName: $request->validated('device_name'),
                fcmToken: $request->validated('fcm_token'),
            );

            return $this->response->success($result, 'Login successful');
        } catch (\Exception $e) {
            return $this->response->error($e->getMessage(), code: (int) $e->getCode() ?: 401);
        }
    }

    /**
     * POST /api/auth/refresh
     */
    public function refresh(RefreshRequest $request): JsonResponse
    {
        try {
            $result = $this->authService->refresh(
                refreshToken: $request->validated('refresh_token'),
                deviceId: $request->validated('device_id'),
            );

            return $this->response->success($result, 'Token refreshed');
        } catch (\Exception $e) {
            return $this->response->error($e->getMessage(), code: 401);
        }
    }

    /**
     * POST /api/auth/logout
     */
    public function logout(Request $request): JsonResponse
    {
        $this->authService->logout(
            user: $request->user(),
            deviceId: $request->header('X-Device-Id', 'unknown'),
        );

        return $this->response->success(message: 'Logged out successfully');
    }

    /**
     * GET /api/auth/me
     */
    public function me(Request $request): JsonResponse
    {
        $user = $this->authService->getProfile($request->user());

        return $this->response->success($user);
    }

    /**
     * PUT /api/auth/me/availability
     */
    public function updateAvailability(UpdateAvailabilityRequest $request): JsonResponse
    {
        $user = $this->authService->updateAvailability(
            user: $request->user(),
            availability: UserAvailability::from($request->validated('availability')),
        );

        return $this->response->success($user, 'Availability updated');
    }
}
