<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Per-number isolation: each ticket (conversation) belongs to the WhatsApp
 * number it was conducted on. The inbox + all ticket resolution scope by this,
 * so 012 and 015 conversations never mix.
 *
 * Existing tickets predate the switch and were all conducted on the primary
 * (012) number — backfill them to it.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('tickets', function (Blueprint $table) {
            $table->string('whatsapp_number', 20)->nullable()->after('channel');
            $table->index(['whatsapp_number', 'last_message_at']);
        });

        $primary = (string) config('whatsapp.wasender.from_number');
        if ($primary !== '') {
            DB::table('tickets')->whereNull('whatsapp_number')->update(['whatsapp_number' => $primary]);
        }
    }

    public function down(): void
    {
        Schema::table('tickets', function (Blueprint $table) {
            $table->dropIndex(['whatsapp_number', 'last_message_at']);
            $table->dropColumn('whatsapp_number');
        });
    }
};
