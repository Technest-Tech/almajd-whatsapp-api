<?php

declare(strict_types=1);

namespace App\Console\Commands;

use Carbon\Carbon;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

/**
 * Storage-hygiene prune of old WhatsApp messages.
 *
 * Deletes whatsapp_messages older than the retention window, drops tickets that
 * become empty as a result, and recomputes each surviving ticket's last-message
 * preview/timestamp and unread_count so the inbox stays consistent.
 *
 * This is NOT a performance fix (the inbox is fast regardless of message count) —
 * it just bounds table growth. Pending (scheduled) outbound messages and rows with
 * a NULL timestamp are never pruned.
 */
class PruneOldMessagesCommand extends Command
{
    protected $signature = 'messages:prune {--days=30 : Retention window in days; messages older than this are deleted} {--dry-run : Report what would be deleted without deleting}';

    protected $description = 'Delete WhatsApp messages older than the retention window (default 30 days) and clean up emptied tickets.';

    public function handle(): int
    {
        $days   = max(1, (int) $this->option('days'));
        $dryRun = (bool) $this->option('dry-run');
        $cutoff = Carbon::now()->subDays($days);

        $base = fn () => DB::table('whatsapp_messages')
            ->whereNotNull('timestamp')
            ->where('timestamp', '<', $cutoff)
            ->where('delivery_status', '!=', 'scheduled');

        $toDelete = (clone $base())->count();

        if ($toDelete === 0) {
            $this->info("✅ messages:prune — nothing older than {$days} days (cutoff {$cutoff->toDateTimeString()}).");
            return Command::SUCCESS;
        }

        $affectedTicketIds = (clone $base())->whereNotNull('ticket_id')
            ->distinct()->pluck('ticket_id');

        if ($dryRun) {
            $this->warn("DRY RUN: would delete {$toDelete} messages older than {$days} days, touching {$affectedTicketIds->count()} tickets.");
            return Command::SUCCESS;
        }

        DB::beginTransaction();
        try {
            // delete old messages in chunks to keep the transaction light
            $deleted = 0;
            do {
                $ids = (clone $base())->orderBy('id')->limit(5000)->pluck('id');
                if ($ids->isEmpty()) {
                    break;
                }
                $deleted += DB::table('whatsapp_messages')->whereIn('id', $ids)->delete();
            } while ($ids->count() === 5000);

            // tickets emptied by the prune -> delete (cascades logs/notes/tags)
            $emptyTicketIds = DB::table('tickets')
                ->whereIn('id', $affectedTicketIds)
                ->whereNotExists(function ($q) {
                    $q->select(DB::raw(1))->from('whatsapp_messages')
                      ->whereColumn('whatsapp_messages.ticket_id', 'tickets.id');
                })->pluck('id');
            $deletedTickets = $emptyTicketIds->isNotEmpty()
                ? DB::table('tickets')->whereIn('id', $emptyTicketIds)->delete()
                : 0;

            // recompute last_message_* and cap unread_count for surviving affected tickets
            $survivors = $affectedTicketIds->diff($emptyTicketIds);
            foreach ($survivors as $tid) {
                $last = DB::table('whatsapp_messages')->where('ticket_id', $tid)
                    ->orderByDesc('timestamp')->first();
                if ($last) {
                    DB::table('tickets')->where('id', $tid)->update([
                        'last_message_at'      => $last->timestamp,
                        'last_message_preview' => Str::limit((string) ($last->content ?? 'Media Message'), 100),
                    ]);
                }
                $inbound = DB::table('whatsapp_messages')->where('ticket_id', $tid)
                    ->where('direction', 'inbound')->count();
                DB::table('tickets')->where('id', $tid)->where('unread_count', '>', $inbound)
                    ->update(['unread_count' => $inbound]);
            }

            DB::commit();
        } catch (\Throwable $e) {
            DB::rollBack();
            $this->error('messages:prune failed: ' . $e->getMessage());
            Log::error('messages:prune failed', ['error' => $e->getMessage()]);
            return Command::FAILURE;
        }

        $msg = "messages:prune — deleted {$deleted} messages (>{$days}d), removed {$deletedTickets} empty tickets, recomputed {$survivors->count()} survivors.";
        $this->info('✅ ' . $msg);
        Log::channel('reminder')->info($msg);

        return Command::SUCCESS;
    }
}
