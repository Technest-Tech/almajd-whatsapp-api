<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('whatsapp_templates', function (Blueprint $table) {
            $table->id();
            $table->string('name')->unique();
            $table->string('language', 10)->default('ar');
            $table->string('category', 100)->nullable();
            $table->text('body_template');
            $table->string('header_type', 20)->nullable(); // none/text/image/document
            $table->string('status', 20)->default('pending'); // approved/pending/rejected
            $table->timestamps();
        });

        Schema::create('whatsapp_messages', function (Blueprint $table) {
            $table->id();
            $table->string('wa_message_id')->unique();
            $table->foreignId('ticket_id')->nullable()->constrained()->nullOnDelete();
            $table->string('direction', 10); // inbound/outbound
            $table->string('from_number', 20);
            $table->string('to_number', 20);
            $table->string('message_type', 20); // text/image/audio/video/document/template
            $table->text('content')->nullable();
            $table->string('media_url', 500)->nullable();
            $table->string('media_mime_type', 100)->nullable();
            $table->string('template_name')->nullable();
            $table->string('delivery_status', 20)->default('scheduled');
            $table->text('failure_reason')->nullable();
            $table->unsignedSmallInteger('retry_count')->default(0);
            $table->string('idempotency_key')->unique()->nullable();
            $table->foreignId('sent_by_id')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('timestamp');
            $table->timestamp('created_at')->useCurrent();

            $table->index('wa_message_id');
            $table->index('direction');
            $table->index('from_number');
            $table->index('timestamp');
            $table->index('ticket_id');
        });

        Schema::create('delivery_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('message_id')->nullable()->constrained('whatsapp_messages')->nullOnDelete();
            $table->foreignId('reminder_job_id')->nullable();
            $table->string('status', 20); // scheduled/sent/delivered/read/failed
            $table->jsonb('bsp_response')->nullable();
            $table->text('failure_reason')->nullable();
            $table->timestamp('attempted_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('delivery_logs');
        Schema::dropIfExists('whatsapp_messages');
        Schema::dropIfExists('whatsapp_templates');
    }
};
