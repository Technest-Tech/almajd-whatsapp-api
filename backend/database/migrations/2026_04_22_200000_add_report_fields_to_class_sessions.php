<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('class_sessions', function (Blueprint $table) {
            // The raw report text submitted by the teacher
            $table->text('teacher_report')->nullable()->after('attendance_status');

            // none | awaiting | confirming | confirmed
            // - none       : report not yet requested (session not completed yet)
            // - awaiting   : system asked teacher for a report; waiting
            // - confirming : teacher sent a candidate report; waiting for their poll confirmation
            // - confirmed  : report confirmed by teacher and forwarded to student
            $table->string('report_status', 20)->default('none')->after('teacher_report');

            // How many nudge messages have been sent (max 2 to avoid spam)
            $table->unsignedTinyInteger('report_nudge_count')->default(0)->after('report_status');
        });
    }

    public function down(): void
    {
        Schema::table('class_sessions', function (Blueprint $table) {
            $table->dropColumn(['teacher_report', 'report_status', 'report_nudge_count']);
        });
    }
};
