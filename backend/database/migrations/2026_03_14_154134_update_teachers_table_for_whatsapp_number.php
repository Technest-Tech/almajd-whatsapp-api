<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // Idempotent: same as 2026_03_13 (production may have run partial / alternate schema).
        if (Schema::hasColumn('teachers', 'phone') && ! Schema::hasColumn('teachers', 'whatsapp_number')) {
            Schema::table('teachers', function (Blueprint $table) {
                $table->renameColumn('phone', 'whatsapp_number');
            });
        }

        $toDrop = array_values(array_filter(
            ['email', 'notes'],
            static fn (string $col): bool => Schema::hasColumn('teachers', $col),
        ));
        if ($toDrop !== []) {
            Schema::table('teachers', function (Blueprint $table) use ($toDrop) {
                $table->dropColumn($toDrop);
            });
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('teachers', function (Blueprint $table) {
            $table->renameColumn('whatsapp_number', 'phone');
            $table->string('email')->nullable();
            $table->text('notes')->nullable();
        });
    }
};
