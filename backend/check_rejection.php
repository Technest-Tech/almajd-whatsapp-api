<?php

use App\Services\TemplateService;
use Illuminate\Support\Facades\Http;

try {
    $accountSid = config('whatsapp.twilio.account_sid');
    $authToken = config('whatsapp.twilio.auth_token');

    $sids = [
        'HX91a529bbcfd7d80a244ed51d7a149284',
        'HX6561e04cd79a6bcaa2b7d7c2e71d33a0',
        'HXebce9ec9e48ba3a22b51ba778eccedbe',
        'HX62df30169512542d1175a1f3be7c939e'
    ];

    foreach ($sids as $sid) {
        $approvalResponse = Http::withBasicAuth($accountSid, $authToken)
            ->get("https://content.twilio.com/v1/Content/{$sid}/ApprovalRequests");
            
        if ($approvalResponse->successful()) {
            $info = $approvalResponse->json('whatsapp', []);
            echo "SID: $sid\n";
            echo "Status: " . ($info['status'] ?? 'N/A') . "\n";
            echo "Rejection Reason: " . ($info['rejection_reason'] ?? 'None') . "\n\n";
        } else {
            echo "Failed to fetch $sid: " . $approvalResponse->status() . "\n";
            echo $approvalResponse->body() . "\n\n";
        }
    }
} catch (\Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
