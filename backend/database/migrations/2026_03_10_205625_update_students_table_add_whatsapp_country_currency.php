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
        Schema::table('students', function (Blueprint $table) {
            $table->dropForeign(['guardian_id']);
            $table->dropColumn(['guardian_id', 'phone']);
            $table->string('whatsapp_number', 20)->nullable()->after('name');
            $table->string('country', 100)->nullable()->after('whatsapp_number');
            $table->string('currency', 10)->nullable()->after('country');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('students', function (Blueprint $table) {
            $table->dropColumn(['whatsapp_number', 'country', 'currency']);
            $table->foreignId('guardian_id')->nullable()->constrained()->nullOnDelete();
            $table->string('phone', 20)->nullable();
        });
    }
};
