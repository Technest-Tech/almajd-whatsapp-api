<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Where the message is physically SENT. When null, sends go to
     * recipient_phone (the legacy 1:1 behaviour). When set to a group JID
     * (...@g.us), the reminder/poll is posted to the shared teacher↔student
     * group instead — while recipient_phone stays the individual's personal
     * number so inbound vote/report matching keeps working.
     */
    public function up(): void
    {
        Schema::table('reminders', function (Blueprint $table) {
            $table->string('destination_jid')->nullable()->after('recipient_phone');
        });
    }

    public function down(): void
    {
        Schema::table('reminders', function (Blueprint $table) {
            $table->dropColumn('destination_jid');
        });
    }
};
