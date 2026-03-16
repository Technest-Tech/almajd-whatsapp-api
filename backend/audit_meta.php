<?php

use App\Models\WhatsappTemplate;
use Illuminate\Support\Facades\Http;

$accountSid = config('whatsapp.twilio.account_sid');
$authToken = config('whatsapp.twilio.auth_token');

$templates = WhatsappTemplate::whereNotNull('content_sid')->get();

foreach ($templates as $t) {
    if (strlen($t->content_sid) < 10) continue; // skip mock values
    
    $approvalResponse = Http::withBasicAuth($accountSid, $authToken)
        ->get("https://content.twilio.com/v1/Content/{$t->content_sid}/ApprovalRequests");
        
    if ($approvalResponse->successful()) {
        $info = $approvalResponse->json('whatsapp', []);
        echo "Template: {$t->name}\n";
        echo "SID: {$t->content_sid}\n";
        echo "Status: " . ($info['status'] ?? 'N/A') . "\n";
        echo "Rejection Reason: " . ($info['rejection_reason'] ?? 'None') . "\n\n";
    } else {
        echo "Failed to fetch {$t->content_sid}: " . $approvalResponse->status() . "\n";
    }
}
