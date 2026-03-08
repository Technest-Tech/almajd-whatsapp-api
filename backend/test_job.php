<?php
require __DIR__.'/vendor/autoload.php';
$app = require_once __DIR__.'/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

try {
    $payload = [
        'MessageSid' => 'SMTESTJOB_' . time(),
        'From' => 'whatsapp:+201207220414',
        'To' => 'whatsapp:+14155238886',
        'Body' => 'Hello from local troubleshooting script',
        'NumMedia' => '0'
    ];
    $job = new \App\Jobs\ProcessTwilioInboundMessageJob($payload);
    $job->handle();
    echo "Job Executed Successfully. \n";
} catch (\Exception $e) {
    echo "Job Failed: " . $e->getMessage() . "\n" . $e->getTraceAsString() . "\n";
}
