<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('tickets', function (Blueprint $table) {
            $table->foreignId('handling_by')
                ->nullable()
                ->constrained('users')
                ->nullOnDelete()
                ->after('session_supervisor_id');

            $table->timestamp('handling_until')
                ->nullable()
                ->after('handling_by');
        });
    }

    public function down(): void
    {
        Schema::table('tickets', function (Blueprint $table) {
            $table->dropForeign(['handling_by']);
            $table->dropColumn(['handling_by', 'handling_until']);
        });
    }
};
