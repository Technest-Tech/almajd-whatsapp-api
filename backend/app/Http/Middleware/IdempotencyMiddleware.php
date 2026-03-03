<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Redis;
use Symfony\Component\HttpFoundation\Response;

class IdempotencyMiddleware
{
    /**
     * Prevent duplicate processing of identical WhatsApp webhook payloads.
     * Uses the wamid (WhatsApp message ID) as the idempotency key via Redis.
     */
    public function handle(Request $request, Closure $next): Response
    {
        $wamid = $this->extractWamid($request);

        if (!$wamid) {
            // No message ID → let it through (might be a status update)
            return $next($request);
        }

        $redisKey = "wa:idempotent:{$wamid}";

        // Try to acquire (SET NX with 60s TTL)
        $acquired = Redis::set($redisKey, '1', 'EX', 60, 'NX');

        if (!$acquired) {
            // Already processed — return 200 OK silently
            return response()->json([
                'success' => true,
                'message' => 'Already processed',
            ], 200);
        }

        return $next($request);
    }

    /**
     * Extract WhatsApp message ID from the BSP webhook payload.
     */
    private function extractWamid(Request $request): ?string
    {
        $data = $request->input('entry.0.changes.0.value.messages.0.id');

        return is_string($data) ? $data : null;
    }
}
