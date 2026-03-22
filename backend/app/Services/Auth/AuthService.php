<?php

declare(strict_types=1);

namespace App\Services\Auth;

use App\Enums\UserAvailability;
use App\Models\DeviceSession;
use App\Models\User;
use App\Services\SessionLoadBalancerService;
use Illuminate\Support\Str;
use PHPOpenSourceSaver\JWTAuth\Facades\JWTAuth;

class AuthService
{
    public function __construct(
        private readonly SessionLoadBalancerService $sessionLoadBalancer,
    ) {}

    /**
     * Authenticate user with email/password, create device session, and return tokens.
     *
     * @return array{access_token: string, refresh_token: string, token_type: string, expires_in: int, user: User}
     * @throws \Exception
     */
    public function login(string $email, string $password, string $deviceId, ?string $deviceName = null, ?string $fcmToken = null): array
    {
        $token = auth('api')->attempt(['email' => $email, 'password' => $password]);

        if (!$token) {
            throw new \Exception('Invalid credentials', 401);
        }

        /** @var User $user */
        $user = auth('api')->user();
        $refreshToken = Str::random(64);

        // Upsert device session (one per user+device combination)
        DeviceSession::updateOrCreate(
            ['user_id' => $user->id, 'device_id' => $deviceId],
            [
                'device_name'    => $deviceName,
                'fcm_token'      => $fcmToken,
                'refresh_token'  => hash('sha256', $refreshToken),
                'last_active_at' => now(),
                'expires_at'     => now()->addDays(7),
            ]
        );

        if ($user->hasAnyRole(['supervisor', 'senior_supervisor'], 'api')) {
            $user->update(['availability' => UserAvailability::Unavailable]);
            $this->sessionLoadBalancer->releaseSessionsFromSupervisor($user->id);
            $user->refresh();
        }

        $user->load('roles', 'permissions', 'shifts');

        return [
            'access_token'  => $token,
            'refresh_token' => $refreshToken,
            'token_type'    => 'bearer',
            'expires_in'    => config('jwt.ttl') * 60,
            'user'          => $user,
        ];
    }

    /**
     * Refresh JWT using a valid refresh token from device_sessions.
     *
     * @return array{access_token: string, token_type: string, expires_in: int}
     * @throws \Exception
     */
    public function refresh(string $refreshToken, string $deviceId): array
    {
        $session = DeviceSession::where('device_id', $deviceId)
            ->where('refresh_token', hash('sha256', $refreshToken))
            ->where('expires_at', '>', now())
            ->first();

        if (!$session) {
            throw new \Exception('Invalid or expired refresh token', 401);
        }

        /** @var User $user */
        $user = $session->user;
        $newToken = JWTAuth::fromUser($user);

        $session->update(['last_active_at' => now()]);

        return [
            'access_token' => $newToken,
            'token_type'   => 'bearer',
            'expires_in'   => config('jwt.ttl') * 60,
        ];
    }

    /**
     * Logout the current user: invalidate JWT + delete device session.
     */
    public function logout(User $user, string $deviceId): void
    {
        DeviceSession::where('user_id', $user->id)
            ->where('device_id', $deviceId)
            ->delete();

        try {
            JWTAuth::invalidate(JWTAuth::getToken());
        } catch (\Exception) {
            // Token may already be invalid — ignore
        }
    }

    /**
     * Get the authenticated user with full role/permission/shifts data.
     */
    public function getProfile(User $user): User
    {
        return $user->load('roles', 'permissions', 'shifts');
    }

    /**
     * Update the user's availability status.
     */
    public function updateAvailability(User $user, UserAvailability $availability): User
    {
        $user->update(['availability' => $availability]);
        $user->refresh();

        if ($user->hasAnyRole(['supervisor', 'senior_supervisor'], 'api')) {
            if ($availability === UserAvailability::Available) {
                $this->sessionLoadBalancer->distributeUnassignedGlobally();
            } elseif (in_array($availability, [UserAvailability::Busy, UserAvailability::Unavailable], true)) {
                $this->sessionLoadBalancer->releaseSessionsFromSupervisor($user->id);
            }
        }

        return $user;
    }
}
