<?php

declare(strict_types=1);

namespace App\Jobs;

use App\Models\ClassSession;
use App\Models\Reminder;
use App\Services\WhatsApp\WhatsAppServiceInterface;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

class SendSessionRemindersJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public function __construct()
    {
        $this->onQueue('default');
    }

    /**
     * Send pending reminders that are due.
     * Runs every minute via scheduler.
     */
    public function handle(WhatsAppServiceInterface $whatsAppService): void
    {
        $dueReminders = Reminder::where('status', 'pending')
            ->where('scheduled_at', '<=', now())
            ->limit(50)
            ->get();

        foreach ($dueReminders as $reminder) {
            try {
                if ($reminder->template_name) {
                    $whatsAppService->sendTemplate(
                        to: $reminder->recipient_phone,
                        templateName: $reminder->template_name,
                        params: ['name' => $reminder->recipient_name ?? ''],
                    );
                } else {
                    $whatsAppService->sendText(
                        to: $reminder->recipient_phone,
                        message: $reminder->message_body ?? '',
                    );
                }

                $reminder->update([
                    'status'  => 'sent',
                    'sent_at' => now(),
                ]);

                Log::info("Reminder #{$reminder->id} sent to {$reminder->recipient_phone}");

            } catch (\Throwable $e) {
                $reminder->update([
                    'status'         => 'failed',
                    'failure_reason' => $e->getMessage(),
                ]);

                Log::error("Reminder #{$reminder->id} failed: {$e->getMessage()}");
            }
        }
    }
}
