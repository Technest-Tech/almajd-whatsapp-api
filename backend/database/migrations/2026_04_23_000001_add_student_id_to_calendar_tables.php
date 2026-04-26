<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('calendar_teacher_timetables', function (Blueprint $table) {
            $table->unsignedBigInteger('student_id')->nullable()->after('student_name');
            $table->foreign('student_id')->references('id')->on('students')->nullOnDelete();
        });

        Schema::table('calendar_exceptional_classes', function (Blueprint $table) {
            $table->unsignedBigInteger('student_id')->nullable()->after('student_name');
            $table->foreign('student_id')->references('id')->on('students')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('calendar_teacher_timetables', function (Blueprint $table) {
            $table->dropForeign(['student_id']);
            $table->dropColumn('student_id');
        });

        Schema::table('calendar_exceptional_classes', function (Blueprint $table) {
            $table->dropForeign(['student_id']);
            $table->dropColumn('student_id');
        });
    }
};
