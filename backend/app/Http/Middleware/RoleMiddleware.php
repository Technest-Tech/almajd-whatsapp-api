<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use App\Services\ApiResponseService;
use Symfony\Component\HttpFoundation\Response;

class RoleMiddleware
{
    public function __construct(private readonly ApiResponseService $response)
    {}

    /**
     * Handle request — check if user has at least one of the specified roles.
     * Usage: ->middleware('role:admin,supervisor')
     */
    public function handle(Request $request, Closure $next, string ...$roles): Response
    {
        $user = $request->user();

        if (!$user || !$user->hasAnyRole($roles)) {
            return $this->response->error('Forbidden: insufficient role', code: 403);
        }

        return $next($request);
    }
}
