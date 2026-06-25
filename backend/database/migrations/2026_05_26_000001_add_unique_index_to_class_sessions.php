<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Index is already applied directly on production to stop ongoing duplication.
        // This migration is a no-op if the index already exists.
        if (!$this->indexExists()) {
            Schema::table('class_sessions', function (Blueprint $table) {
                $table->unique(['student_id', 'teacher_id', 'session_date', 'start_time'], 'unique_session_slot');
            });
        }
    }

    public function down(): void
    {
        Schema::table('class_sessions', function (Blueprint $table) {
            $table->dropUnique('unique_session_slot');
        });
    }

    private function indexExists(): bool
    {
        return collect(\Illuminate\Support\Facades\DB::select("SHOW INDEX FROM class_sessions WHERE Key_name = 'unique_session_slot'"))->isNotEmpty();
    }
};
