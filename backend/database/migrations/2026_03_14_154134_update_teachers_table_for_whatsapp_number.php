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
        Schema::table('teachers', function (Blueprint $table) {
            $table->renameColumn('phone', 'whatsapp_number');
            $table->dropColumn(['email', 'notes']);
        });
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
