<?php

declare(strict_types=1);

namespace App\Http\Controllers\Webhook;

use App\Http\Controllers\Controller;
use App\Jobs\ProcessInboundMessageJob;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class WhatsAppWebhookController extends Controller
{
    /**
     * GET /api/webhooks/whatsapp/verify
     * Handle BSP webhook verification challenge.
     */
    public function verify(Request $request): mixed
    {
        $verifyToken = config('whatsapp.verify_token');
        $mode        = $request->query('hub_mode');
        $token       = $request->query('hub_verify_token');
        $challenge   = $request->query('hub_challenge');

        if ($mode === 'subscribe' && $token === $verifyToken) {
            return response($challenge, 200)->header('Content-Type', 'text/plain');
        }

        return response()->json(['success' => false, 'message' => 'Verification failed'], 403);
    }

    /**
     * POST /api/webhooks/whatsapp
     * Receive inbound webhook from BSP.
     * Middleware: webhook.signature, idempotency
     */
    public function receive(Request $request): JsonResponse
    {
        $payload = $request->all();

        // Dispatch asynchronously on high-priority queue
        ProcessInboundMessageJob::dispatch($payload);

        return response()->json(['success' => true, 'message' => 'Received'], 200);
    }

    /**
     * POST /api/webhooks/whatsapp/status
     * Receive delivery status callback from BSP.
     * Middleware: webhook.signature
     */
    public function status(Request $request): JsonResponse
    {
        $statuses = data_get($request->all(), 'entry.0.changes.0.value.statuses', []);

        foreach ($statuses as $statusUpdate) {
            $wamid  = $statusUpdate['id'] ?? null;
            $status = $statusUpdate['status'] ?? null;

            if (!$wamid || !$status) {
                continue;
            }

            $message = \App\Models\WhatsappMessage::where('wa_message_id', $wamid)->first();

            if ($message) {
                $message->update(['delivery_status' => $status]);

                \App\Models\DeliveryLog::create([
                    'message_id'   => $message->id,
                    'status'       => $status,
                    'bsp_response' => $statusUpdate,
                    'attempted_at' => now(),
                ]);
            }
        }

        return response()->json(['success' => true], 200);
    }
}
