<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('calendar_teachers', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('whatsapp')->nullable();
            $table->timestamps();
        });

        Schema::create('calendar_teacher_timetables', function (Blueprint $table) {
            $table->id();
            $table->foreignId('teacher_id')->constrained('calendar_teachers')->cascadeOnDelete();
            $table->string('day'); // Sunday, Monday, etc.
            $table->time('start_time');
            $table->time('finish_time')->nullable();
            $table->string('student_name');
            $table->string('country')->default('canada'); // canada, uk, eg
            $table->string('status')->default('active'); // active, inactive
            $table->date('reactive_date')->nullable();
            $table->date('deleted_date')->nullable();
            $table->timestamps();

            $table->index(['teacher_id', 'day']);
            $table->index(['day', 'start_time']);
            $table->index('student_name');
            $table->index('status');
        });

        Schema::create('calendar_exceptional_classes', function (Blueprint $table) {
            $table->id();
            $table->string('student_name');
            $table->date('date');
            $table->time('time');
            $table->foreignId('teacher_id')->constrained('calendar_teachers')->cascadeOnDelete();
            $table->timestamps();

            $table->index(['date', 'time']);
            $table->index('student_name');
        });

        Schema::create('calendar_students_stops', function (Blueprint $table) {
            $table->id();
            $table->string('student_name');
            $table->date('date_from');
            $table->date('date_to');
            $table->text('reason')->nullable();
            $table->timestamps();

            $table->index(['date_from', 'date_to']);
            $table->index('student_name');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('calendar_students_stops');
        Schema::dropIfExists('calendar_exceptional_classes');
        Schema::dropIfExists('calendar_teacher_timetables');
        Schema::dropIfExists('calendar_teachers');
    }
};
