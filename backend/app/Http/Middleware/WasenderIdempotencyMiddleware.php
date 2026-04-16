<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Symfony\Component\HttpFoundation\Response;

/**
 * Prevent duplicate processing of identical Wasender webhook payloads.
 *
 * Wasender's message ID lives at data.messages.key.id in messages.received events.
 * For other event types (status updates, etc.) we fall through without blocking.
 *
 * Uses Laravel Cache (not Redis directly) so this works with any cache driver
 * (database, file, redis, etc.) without crashing if phpredis is not installed.
 */
class WasenderIdempotencyMiddleware
{
    public function handle(Request $request, Closure $next): Response
    {
        $messageId = $this->extractMessageId($request);

        if (!$messageId) {
            return $next($request);
        }

        $cacheKey = "wa:idempotent:wasender:{$messageId}";

        // add() only stores if the key doesn't exist — atomic idempotency check
        $acquired = Cache::add($cacheKey, '1', now()->addSeconds(60));

        if (!$acquired) {
            // Already processed — silently return 200 OK so Wasender stops retrying
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
