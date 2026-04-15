<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Redis;
use Symfony\Component\HttpFoundation\Response;

/**
 * Prevent duplicate processing of identical Wasender webhook payloads.
 *
 * Wasender's message ID lives at data.messages.key.id in messages.received events.
 * For other event types (status updates, etc.) we fall through without blocking.
 */
class WasenderIdempotencyMiddleware
{
    public function handle(Request $request, Closure $next): Response
    {
        $messageId = $this->extractMessageId($request);

        if (!$messageId) {
            return $next($request);
        }

        $redisKey = "wa:idempotent:wasender:{$messageId}";

        // Acquire a lock for 60 seconds (NX = only set if not exists)
        $acquired = Redis::set($redisKey, '1', 'EX', 60, 'NX');

        if (!$acquired) {
            // Already processed — silently return 200 OK
            return response()->json([
                'success' => true,
                'message' => 'Already processed',
            ], 200);
        }

        return $next($request);
    }

    /**
     * Extract the Wasender message ID from the webhook payload.
     *
     * Payload structure (messages.received event):
     *   { "event": "messages.received", "data": { "messages": { "key": { "id": "3EB0X..." } } } }
     */
    private function extractMessageId(Request $request): ?string
    {
        $id = $request->input('data.messages.key.id');

        return is_string($id) && $id !== '' ? $id : null;
    }
}
