<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('shifts', function (Blueprint $table) {
            // Allow a supervisor to have more than one shift on the same day
            // (e.g. a morning and an evening slot). Replace the (user_id,
            // day_of_week) UNIQUE key with a plain index. The new index must be
            // created BEFORE dropping the unique one, because the user_id
            // foreign key relies on having an index with user_id as its first
            // column.
            $table->index(['user_id', 'day_of_week'], 'shifts_user_id_day_of_week_index');
            $table->dropUnique('shifts_user_id_day_of_week_unique');
        });
    }

    public function down(): void
    {
        Schema::table('shifts', function (Blueprint $table) {
            $table->dropIndex('shifts_user_id_day_of_week_index');
            $table->unique(['user_id', 'day_of_week'], 'shifts_user_id_day_of_week_unique');
        });
    }
};
