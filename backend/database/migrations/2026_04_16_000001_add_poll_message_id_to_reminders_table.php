<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('reminders', function (Blueprint $table) {
            // Stores the Wasender message ID of the poll sent to the teacher.
            // Used to match incoming poll vote webhook events back to the reminder.
            $table->string('poll_message_id')->nullable()->after('confirmation_status');
        });
    }

    public function down(): void
    {
        Schema::table('reminders', function (Blueprint $table) {
            $table->dropColumn('poll_message_id');
        });
    }
};
