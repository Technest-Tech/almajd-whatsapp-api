<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('tickets', function (Blueprint $table) {
            // The supervisor assigned via session load balancing.
            // NULL = unassigned (orphaned chat — visible to admins/senior_supervisors only).
            $table->foreignId('session_supervisor_id')
                ->nullable()
                ->after('assigned_to')
                ->constrained('users')
                ->nullOnDelete();

            // Link ticket to teacher when the contact is a teacher (was missing).
            $table->foreignId('teacher_id')
                ->nullable()
                ->after('student_id')
                ->constrained('teachers')
                ->nullOnDelete();

            $table->index('session_supervisor_id');
        });
    }

    public function down(): void
    {
        Schema::table('tickets', function (Blueprint $table) {
            $table->dropForeign(['session_supervisor_id']);
            $table->dropForeign(['teacher_id']);
            $table->dropColumn(['session_supervisor_id', 'teacher_id']);
        });
    }
};
