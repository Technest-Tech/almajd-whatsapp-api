<?php

declare(strict_types=1);

namespace App\Http\Controllers\Webhook;

use App\Http\Controllers\Controller;
use App\Jobs\ProcessTwilioInboundMessageJob;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

class TwilioWebhookController extends Controller
{
    /**
     * POST /api/webhooks/twilio/whatsapp
     * Receive inbound webhook from Twilio WhatsApp (production sender).
     * Middleware: twilio.signature
     */
    public function receive(Request $request): Response
    {
        $payload = $request->all();
        \Illuminate\Support\Facades\Log::info("Twilio Webhook Reached Controller", $payload);

        // Dispatch to the high-priority queue immediately
        ProcessTwilioInboundMessageJob::dispatch($payload);

        // Twilio requires a fast 200 OK response with empty TwiML or nothing
        return response('', 200)->header('Content-Type', 'text/xml');
    }

    /**
     * POST /api/webhooks/twilio/status
     * Receive delivery status callbacks (sent, delivered, read, failed).
     */
    public function status(Request $request): Response
    {
        $payload = $request->all();
        
        $messageSid = $payload['MessageSid'] ?? null;
        $status     = $payload['MessageStatus'] ?? null;

        if ($messageSid && $status) {
            $message = \App\Models\WhatsappMessage::where('wa_message_id', $messageSid)->first();

            if ($message) {
                // Update specific status log
                $message->update(['delivery_status' => $status]);

                \App\Models\DeliveryLog::create([
                    'message_id'   => $message->id,
                    'status'       => $status,
                    'bsp_response' => $payload,
                    'attempted_at' => now(),
                ]);

                // Broadcast real-time status update so Flutter updates ticks instantly
                event(new \App\Events\TicketMessageStatusUpdated($message));
            }
        }


        return response('', 200)->header('Content-Type', 'text/xml');
    }
}
