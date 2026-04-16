<?php

declare(strict_types=1);

namespace App\Http\Controllers\Webhook;

use App\Http\Controllers\Controller;
use App\Jobs\ProcessWasenderInboundMessageJob;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

/**
 * Handles incoming webhook events from WasenderAPI.
 *
 * Endpoint: POST /api/webhooks/wasender
 * Middleware: wasender.signature, wasender.idempotency
 *
 * All events share a single endpoint. The job determines how to route them
 * based on the `event` field in the JSON payload.
 *
 * Supported event types:
 *   - messages.received   → new inbound message
 *   - messages.upsert     → new inbound OR outbound message
 *   - messages.update     → delivery status change (sent/delivered/read)
 *   - session.status      → WhatsApp session connection changed
 *   - (others)            → logged and ignored
 */
class WasenderWebhookController extends Controller
{
    /**
     * POST /api/webhooks/wasender
     *
     * Receives all Wasender webhook events. Dispatches to the high-priority
     * queue immediately and returns 200 OK fast.
     */
    public function receive(Request $request): JsonResponse
    {
        $payload = $request->all();
        $event   = $payload['event'] ?? 'unknown';

        // Full payload dump for debugging inbound message flow
        Log::channel('single')->info("WasenderAPI Webhook [{$event}]", [
            'full_payload' => json_encode($payload, JSON_UNESCAPED_UNICODE),
        ]);

        ProcessWasenderInboundMessageJob::dispatch($payload);

        return response()->json(['success' => true, 'message' => 'Received'], 200);
    }
}
