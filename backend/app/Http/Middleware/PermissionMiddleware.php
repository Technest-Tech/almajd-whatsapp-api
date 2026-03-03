<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use App\Services\ApiResponseService;
use Symfony\Component\HttpFoundation\Response;

class PermissionMiddleware
{
    public function __construct(private readonly ApiResponseService $response)
    {}

    /**
     * Handle request — check if user has the specified permission.
     * Usage: ->middleware('permission:tickets.view')
     */
    public function handle(Request $request, Closure $next, string $permission): Response
    {
        $user = $request->user();

        if (!$user || !$user->hasPermissionTo($permission)) {
            return $this->response->error('Forbidden: missing permission "' . $permission . '"', code: 403);
        }

        return $next($request);
    }
}
