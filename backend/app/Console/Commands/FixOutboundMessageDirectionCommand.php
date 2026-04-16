<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Enums\DeliveryStatus;
use App\Enums\MessageDirection;
use App\Models\WhatsappMessage;
use Illuminate\Console\Command;

/**
 * Fix historical WhatsApp messages that were sent from the WhatsApp Business
 * App but incorrectly stored as direction=inbound.
 *
 * These messages have:
 *   - direction = 'inbound'
 *   - from_number = our own WhatsApp number (config whatsapp.wasender.from_number)
 *
 * Run once:
 *   php artisan whatsapp:fix-outbound-direction
 */
class FixOutboundMessageDirectionCommand extends Command
{
    protected $signature   = 'whatsapp:fix-outbound-direction {--dry-run : Preview without making changes}';
    protected $description = 'Fix WhatsApp messages sent from our number that were wrongly stored as inbound';

    public function handle(): int
    {
        $ourNumber        = config('whatsapp.wasender.from_number', '');
        $ourNumberNoPlus  = ltrim($ourNumber, '+');

        if (!$ourNumber) {
            $this->error('whatsapp.wasender.from_number is not configured. Aborting.');
            return self::FAILURE;
        }

        $this->info("Our number: {$ourNumber}");

        // Find messages where from_number is OUR number but direction is inbound
        $query = WhatsappMessage::query()
            ->where('direction', MessageDirection::Inbound)
            ->where(function ($q) use ($ourNumber, $ourNumberNoPlus) {
                $q->where('from_number', $ourNumber)
                  ->orWhere('from_number', $ourNumberNoPlus)
                  ->orWhere('from_number', "+{$ourNumberNoPlus}");
            });

        $count = $query->count();

        if ($count === 0) {
            $this->info('No misclassified messages found. Nothing to fix.');
            return self::SUCCESS;
        }

        $this->warn("Found {$count} messages with from_number={$ourNumber} incorrectly stored as inbound.");

        if ($this->option('dry-run')) {
            $this->table(
                ['ID', 'ticket_id', 'from_number', 'direction', 'content'],
                $query->limit(20)->get()->map(fn ($m) => [
                    $m->id,
                    $m->ticket_id,
                    $m->from_number,
                    $m->direction->value,
                    mb_substr($m->content ?? '', 0, 60),
                ])->toArray()
            );
            $this->info('[Dry run] No changes made.');
            return self::SUCCESS;
        }

        if (!$this->confirm("Fix {$count} messages by setting direction=outbound and delivery_status=sent?")) {
            $this->info('Aborted.');
            return self::SUCCESS;
        }

        $fixed = $query->update([
            'direction'       => MessageDirection::Outbound,
            'delivery_status' => DeliveryStatus::Sent,
        ]);

        $this->info("✅ Fixed {$fixed} messages → direction=outbound, delivery_status=sent");

        return self::SUCCESS;
    }
}
