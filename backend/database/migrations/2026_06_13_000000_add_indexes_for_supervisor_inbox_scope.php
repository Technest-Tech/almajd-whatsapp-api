<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Performance indexes for the supervisor inbox scoping query.
 *
 * TicketService::list() / unreadCount() join class_sessions -> students/teachers
 * by whatsapp_number = guardians.phone for every ticket. Without these indexes the
 * supervisor inbox took ~15s (and timed out → "failed to fetch"); with them ~0.6s.
 */
return new class extends Migration
{
    public function up(): void
    {
        $this->addIndex('students', 'whatsapp_number', 'students_whatsapp_number_index');
        $this->addIndex('teachers', 'whatsapp_number', 'teachers_whatsapp_number_index');

        if (Schema::hasTable('class_sessions') && !$this->indexExists('class_sessions', 'class_sessions_session_date_status_index')) {
            DB::statement('CREATE INDEX class_sessions_session_date_status_index ON class_sessions (session_date, status)');
        }
    }

    public function down(): void
    {
        $this->dropIndex('students', 'students_whatsapp_number_index');
        $this->dropIndex('teachers', 'teachers_whatsapp_number_index');
        $this->dropIndex('class_sessions', 'class_sessions_session_date_status_index');
    }

    private function addIndex(string $table, string $column, string $name): void
    {
        if (Schema::hasTable($table) && Schema::hasColumn($table, $column) && !$this->indexExists($table, $name)) {
            DB::statement("CREATE INDEX {$name} ON {$table} ({$column})");
        }
    }

    private function dropIndex(string $table, string $name): void
    {
        if (Schema::hasTable($table) && $this->indexExists($table, $name)) {
            DB::statement("DROP INDEX {$name} ON {$table}");
        }
    }

    private function indexExists(string $table, string $name): bool
    {
        return DB::table('information_schema.statistics')
            ->where('table_schema', DB::raw('DATABASE()'))
            ->where('table_name', $table)
            ->where('index_name', $name)
            ->exists();
    }
};
