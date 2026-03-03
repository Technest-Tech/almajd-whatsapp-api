<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class WebhookSignatureMiddleware
{
    /**
     * Verify the BSP webhook signature (X-Hub-Signature-256 header).
     * Rejects requests with invalid or missing HMAC SHA256 signature.
     */
    public function handle(Request $request, Closure $next): Response
    {
        $signature = $request->header('X-Hub-Signature-256');
        $secret    = config('whatsapp.webhook_secret');

        if (!$signature || !$secret) {
            return response()->json([
                'success' => false,
                'message' => 'Missing webhook signature',
            ], 401);
        }

        $expectedHash = 'sha256=' . hash_hmac('sha256', $request->getContent(), $secret);

        if (!hash_equals($expectedHash, $signature)) {
            return response()->json([
                'success' => false,
                'message' => 'Invalid webhook signature',
            ], 401);
        }

        return $next($request);
    }
}
