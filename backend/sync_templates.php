<?php

use App\Models\WhatsappTemplate;
use App\Services\TemplateService;

try {
    $service = app(TemplateService::class);
    $templates = WhatsappTemplate::whereIn('name', [
        'class_start_reminder',
        'student_late_alert',
        'class_completion_status',
        'new_student_onboarding'
    ])->get();

    foreach ($templates as $t) {
        echo "Processing {$t->name}...\n";
        
        // 1. Clear the dummy content_sid from Seeder so Twilio recreates it natively
        $t->update(['content_sid' => null]);
        
        // 2. Transmit to Twilio Meta Approval Network
        try {
            $service->submitForApproval($t);
            echo "Successfully submitted {$t->name} (SID: {$t->content_sid})\n";
        } catch (\Exception $e) {
            echo "Failed to submit {$t->name}: " . $e->getMessage() . "\n";
        }
    }
} catch (\Exception $e) {
    echo "Fatal Error: " . $e->getMessage() . "\n";
}
