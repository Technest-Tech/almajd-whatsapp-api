<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('reminders', function (Blueprint $table) {
            $table->unique(
                ['class_session_id', 'reminder_phase', 'recipient_type', 'recipient_phone'],
                'reminders_session_phase_recipient_unique'
            );
        });
    }

    public function down(): void
    {
        Schema::table('reminders', function (Blueprint $table) {
            $table->dropUnique('reminders_session_phase_recipient_unique');
        });
    }
};
