<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Ensure students table uses only whatsapp_number (no phone column).
     * If an old "phone" column exists, copy data to whatsapp_number then drop phone.
     */
    public function up(): void
    {
        if (!Schema::hasTable('students')) {
            return;
        }

        $hasPhone = Schema::hasColumn('students', 'phone');
        $hasWhatsapp = Schema::hasColumn('students', 'whatsapp_number');

        if ($hasPhone && $hasWhatsapp) {
            // Copy phone -> whatsapp_number where whatsapp_number is empty, then drop phone
            \DB::table('students')
                ->whereNotNull('phone')
                ->where(function ($q) {
                    $q->whereNull('whatsapp_number')->orWhere('whatsapp_number', '');
                })
                ->update(['whatsapp_number' => \DB::raw('phone')]);
            Schema::table('students', fn (Blueprint $table) => $table->dropColumn('phone'));
        } elseif ($hasPhone && !$hasWhatsapp) {
            // Add whatsapp_number, copy from phone, drop phone
            Schema::table('students', function (Blueprint $table) {
                $table->string('whatsapp_number', 20)->nullable()->after('name');
            });
            \DB::table('students')->whereNotNull('phone')->update(['whatsapp_number' => \DB::raw('phone')]);
            Schema::table('students', fn (Blueprint $table) => $table->dropColumn('phone'));
        }
        // If only whatsapp_number exists (or neither), nothing to do
    }

    public function down(): void
    {
        // Irreversible: we do not re-add phone
    }
};
