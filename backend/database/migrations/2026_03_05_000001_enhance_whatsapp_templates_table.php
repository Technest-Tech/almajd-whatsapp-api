<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('whatsapp_templates', function (Blueprint $table) {
            // Twilio Content API SID (e.g. HXxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx)
            $table->string('content_sid', 64)->nullable()->unique()->after('status');
            // Comma-separated or JSON list of variable names e.g. ["name","course"]
            $table->json('variables_schema')->nullable()->after('content_sid');
            // Optional header / footer text
            $table->string('header_text', 255)->nullable()->after('variables_schema');
            $table->string('footer_text', 255)->nullable()->after('header_text');
            // Rejection reason from Meta
            $table->text('rejection_reason')->nullable()->after('footer_text');
            // Twilio status last synced at
            $table->timestamp('synced_at')->nullable()->after('rejection_reason');
        });

        // Add template_variables to whatsapp_messages for storing filled vars
        Schema::table('whatsapp_messages', function (Blueprint $table) {
            $table->json('template_variables')->nullable()->after('template_name');
        });
    }

    public function down(): void
    {
        Schema::table('whatsapp_messages', function (Blueprint $table) {
            $table->dropColumn('template_variables');
        });

        Schema::table('whatsapp_templates', function (Blueprint $table) {
            $table->dropColumn([
                'content_sid', 'variables_schema', 'header_text',
                'footer_text', 'rejection_reason', 'synced_at',
            ]);
        });
    }
};
