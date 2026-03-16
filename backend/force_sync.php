<?php

use App\Services\TemplateService;

try {
    echo "Starting Twilio Template Sync...\n";
    $service = app(TemplateService::class);
    $updatedCount = $service->syncFromTwilio();
    echo "Sync Complete! Updated $updatedCount templates.\n";
    
    // Let's print the current status of the templates we care about
    $templates = \App\Models\WhatsappTemplate::whereIn('name', [
        'class_start_reminder',
        'student_late_alert',
        'class_completion_status',
        'new_student_onboarding'
    ])->get();
    
    echo "\nCurrent Statuses in DB:\n";
    foreach ($templates as $t) {
        echo "- {$t->name}: " . ($t->status->value ?? $t->status) . "\n";
    }
} catch (\Exception $e) {
    echo "Sync Failed: " . $e->getMessage() . "\n";
}
