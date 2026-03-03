<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('teachers', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('phone', 20)->nullable();
            $table->string('email')->nullable();
            $table->text('notes')->nullable();
            $table->timestamps();
            $table->softDeletes();
        });

        Schema::create('schedules', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->text('description')->nullable();
            $table->date('start_date');
            $table->date('end_date');
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });

        Schema::create('schedule_entries', function (Blueprint $table) {
            $table->id();
            $table->foreignId('schedule_id')->nullable()->constrained()->cascadeOnDelete();
            $table->foreignId('student_id')->nullable()->constrained()->cascadeOnDelete();
            $table->foreignId('teacher_id')->nullable()->constrained()->nullOnDelete();
            $table->string('title');
            $table->unsignedSmallInteger('day_of_week'); // 0=Sun
            $table->time('start_time');
            $table->time('end_time');
            $table->string('recurrence', 20)->default('weekly'); // weekly, biweekly, once
            $table->text('notes')->nullable();
            $table->timestamps();

            $table->index(['schedule_id', 'day_of_week']);
            $table->index(['student_id', 'day_of_week']);
        });

        Schema::create('class_sessions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('schedule_entry_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('student_id')->nullable()->constrained()->cascadeOnDelete();
            $table->foreignId('teacher_id')->nullable()->constrained()->nullOnDelete();
            $table->string('title');
            $table->date('session_date');
            $table->time('start_time');
            $table->time('end_time');
            $table->string('status', 20)->default('scheduled'); // scheduled, completed, cancelled, rescheduled
            $table->text('cancellation_reason')->nullable();
            $table->date('rescheduled_date')->nullable();
            $table->time('rescheduled_start_time')->nullable();
            $table->time('rescheduled_end_time')->nullable();
            $table->timestamps();

            $table->index('session_date');
            $table->index('status');
            $table->index(['student_id', 'session_date']);
        });

        Schema::create('reminders', function (Blueprint $table) {
            $table->id();
            $table->string('type', 50); // session_reminder, guardian_notification, custom
            $table->foreignId('class_session_id')->nullable()->constrained()->nullOnDelete();
            $table->string('recipient_phone', 20);
            $table->string('recipient_name')->nullable();
            $table->string('template_name')->nullable();
            $table->text('message_body')->nullable();
            $table->timestamp('scheduled_at');
            $table->timestamp('sent_at')->nullable();
            $table->string('status', 20)->default('pending'); // pending, sent, failed, cancelled
            $table->text('failure_reason')->nullable();
            $table->timestamps();

            $table->index('scheduled_at');
            $table->index('status');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('reminders');
        Schema::dropIfExists('class_sessions');
        Schema::dropIfExists('schedule_entries');
        Schema::dropIfExists('schedules');
        Schema::dropIfExists('teachers');
    }
};
