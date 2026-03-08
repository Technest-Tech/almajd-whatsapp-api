<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Add new columns to reminders
        Schema::table('reminders', function (Blueprint $table) {
            $table->string('recipient_type', 20)->default('student')->after('type');
            // before, at_start, after
            $table->string('reminder_phase', 20)->default('before')->after('recipient_type');
            // awaiting, confirmed, denied, no_reply
            $table->string('confirmation_status', 20)->nullable()->after('status');
        });

        // Add attendance_status to class_sessions
        Schema::table('class_sessions', function (Blueprint $table) {
            $table->string('attendance_status', 30)->default('pending')
                ->after('status'); // pending, teacher_joined, student_absent, both_joined, no_show
        });
    }

    public function down(): void
    {
        Schema::table('reminders', function (Blueprint $table) {
            $table->dropColumn(['recipient_type', 'reminder_phase', 'confirmation_status']);
        });
        Schema::table('class_sessions', function (Blueprint $table) {
            $table->dropColumn('attendance_status');
        });
    }
};
