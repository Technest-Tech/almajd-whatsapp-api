<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Verify that incoming webhook requests originate from WasenderAPI.
 *
 * Wasender sends a shared secret in the X-Webhook-Signature header.
 * We compare it directly against our stored WASENDER_WEBHOOK_SECRET.
 *
 * Configure in Session settings on the Wasender dashboard.
 */
class WasenderSignatureMiddleware
{
    public function handle(Request $request, Closure $next): Response
    {
        $secret    = config('whatsapp.wasender.webhook_secret');
        $signature = $request->header('X-Webhook-Signature');

        // If no secret configured, skip validation (dev/sandbox mode)
        if (!$secret) {
            return $next($request);
        }

        if (!$signature) {
            return response()->json([
                'success' => false,
                'message' => 'Missing X-Webhook-Signature header',
            ], 401);
        }

        if (!hash_equals($secret, $signature)) {
            return response()->json([
                'success' => false,
                'message' => 'Invalid webhook signature',
            ], 401);
        }

        return $next($request);
    }
}
