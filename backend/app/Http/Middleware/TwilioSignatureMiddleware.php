<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Twilio\Security\RequestValidator;

class TwilioSignatureMiddleware
{
    /**
     * Verify that incoming requests are authentically from Twilio.
     * Rejects requests with invalid or missing X-Twilio-Signature using Twilio SDK.
     */
    public function handle(Request $request, Closure $next)
    {
        $signature = $request->header('X-Twilio-Signature');
        $authToken = config('whatsapp.twilio.auth_token');

        if (!$signature || !$authToken) {
            return response()->json([
                'success' => false,
                'message' => 'Missing Twilio signature or Auth Token configuration',
            ], 401);
        }

        // The URL Twilio thinks it requested (needs full scheme + host + path)
        $url = $request->fullUrl();

        // Twilio requires form POST parameters to be parsed properly in signature validation
        $postVars = $request->isMethod('POST') ? $request->post() : [];

        $validator = new RequestValidator($authToken);

        if (!$validator->validate($signature, $url, $postVars)) {
            return response()->json([
                'success' => false,
                'message' => 'Twilio Signature validation failed',
            ], 401);
        }

        return $next($request);
    }
}
