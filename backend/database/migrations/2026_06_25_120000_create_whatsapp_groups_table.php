<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Maps a teacher↔student pair to the shared WhatsApp group they belong to.
     *
     * When a row exists for a session's (teacher_id, student_id), reminders and
     * polls for that session are sent to `group_jid` (the group) instead of the
     * individual phones. Responses are still matched back to the individual by
     * their personal phone (reminders.recipient_phone), so tracking is unaffected.
     */
    public function up(): void
    {
        Schema::create('whatsapp_groups', function (Blueprint $table) {
            $table->id();

            $table->foreignId('teacher_id')->nullable()->constrained('teachers')->nullOnDelete();
            $table->foreignId('student_id')->nullable()->constrained('students')->nullOnDelete();

            // The WhatsApp group JID, e.g. "201204131545-1680000000@g.us".
            $table->string('group_jid');
            // Human-friendly group subject/name (from Wasender), for display.
            $table->string('group_name')->nullable();

            // The Wasender sender number (E.164) that OWNS this group — i.e. the
            // active number when it was linked. A group only works from the
            // number that is a member of it, so routing only uses this group
            // while that number is the active session; otherwise it falls back
            // to the private number. Lets the same pair have a 012 group AND a
            // 015 group, each used only when its number is active.
            $table->string('whatsapp_number')->nullable();

            $table->boolean('is_active')->default(true);

            $table->timestamps();

            // One mapping per teacher↔student pair PER owning number.
            $table->unique(['teacher_id', 'student_id', 'whatsapp_number']);
            $table->index('group_jid');
            $table->index('whatsapp_number');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('whatsapp_groups');
    }
};
