<?php

try {
    echo "Starting Stats Fetch...\n";
    $service = app(\App\Services\Ticket\TicketService::class);
    $stats = $service->stats();
    
    echo json_encode($stats, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) . "\n";
    
    echo "\nStats Fetch Complete!\n";
} catch (\Exception $e) {
    echo "Sync Failed: " . $e->getMessage() . "\n";
}
