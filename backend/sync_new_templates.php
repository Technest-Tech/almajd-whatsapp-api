<?php

use App\Models\WhatsappTemplate;
use App\Services\TemplateService;
use App\Enums\TemplateStatus;

echo "Syncing Templates again (with fresh model instances)...\n";

$service = app(TemplateService::class);

$names = [
    'class_start_reminder',
    'student_late_alert',
    'class_completion_status',
    'new_student_onboarding'
];

foreach ($names as $name) {
    $template = WhatsappTemplate::where('name', $name)->first();
    if (!$template) continue;

    if ($template->content_sid) {
        try {
            $service->delete($template);
            echo "Deleted old Twilio Template for: {$template->name} ({$template->content_sid})\n";
        } catch (\Exception $e) {
            echo "Could not delete old Twilio entry: " . $e->getMessage() . "\n";
        }
    }

    // Force strict nullification and save
    $template->content_sid = null;
    $template->status = TemplateStatus::Draft;
    $template->save();

    echo "Re-creating " . $template->name . "...\n";

    try {
        // Fetch completely fresh from DB to avoid any caching issues
        $freshTemplate = WhatsappTemplate::where('name', $name)->first();
        $service->submitForApproval($freshTemplate);
        
        // Refresh again to get the assigned SID
        $freshTemplate->refresh();
        echo "Successfully Submitted! New SID: " . $freshTemplate->content_sid . "\n";
    } catch (\Exception $e) {
        echo "Failed to submit {$template->name}: " . $e->getMessage() . "\n";
    }
    echo "-----\n";
}
echo "Done! Re-run check_rejection.php if they fail again.\n";
