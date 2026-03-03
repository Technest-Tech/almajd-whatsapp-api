<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('guardians', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('phone', 20)->unique();
            $table->string('email')->nullable();
            $table->text('notes')->nullable();
            $table->timestamps();
            $table->softDeletes();

            $table->index('phone');
        });

        Schema::create('students', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->foreignId('guardian_id')->nullable()->constrained()->nullOnDelete();
            $table->string('phone', 20)->nullable();
            $table->string('student_code', 50)->nullable();
            $table->text('notes')->nullable();
            $table->timestamps();
            $table->softDeletes();

            $table->index('guardian_id');
        });

        Schema::create('tags', function (Blueprint $table) {
            $table->id();
            $table->string('name')->unique();
            $table->string('color', 7)->default('#3B82F6');
            $table->unsignedInteger('sla_first_response_minutes')->nullable();
            $table->unsignedInteger('sla_resolution_minutes')->nullable();
            $table->timestamps();
        });

        Schema::create('tickets', function (Blueprint $table) {
            $table->id();
            $table->string('ticket_number')->unique();
            $table->foreignId('guardian_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('student_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('assigned_to')->nullable()->constrained('users')->nullOnDelete();
            $table->string('status', 20)->default('open');
            $table->string('priority', 20)->default('normal');
            $table->string('channel', 20)->default('whatsapp'); // whatsapp|manual
            $table->text('subject')->nullable();
            $table->text('last_message_preview')->nullable();
            $table->unsignedSmallInteger('escalation_level')->default(0);
            $table->timestamp('first_response_at')->nullable();
            $table->timestamp('resolved_at')->nullable();
            $table->timestamp('closed_at')->nullable();
            $table->timestamp('sla_deadline_at')->nullable();
            $table->boolean('sla_breached')->default(false);
            $table->timestamps();

            $table->index('status');
            $table->index('assigned_to');
            $table->index('guardian_id');
            $table->index('priority');
            $table->index('sla_breached');
            $table->index('created_at');
        });

        Schema::create('ticket_tag', function (Blueprint $table) {
            $table->foreignId('ticket_id')->constrained()->cascadeOnDelete();
            $table->foreignId('tag_id')->constrained()->cascadeOnDelete();
            $table->primary(['ticket_id', 'tag_id']);
        });

        Schema::create('ticket_notes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ticket_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->text('content');
            $table->boolean('is_internal')->default(true); // internal note (not sent to guardian)
            $table->timestamp('created_at')->useCurrent();
        });

        Schema::create('ticket_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ticket_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->string('action', 50); // assigned, status_changed, escalated, etc.
            $table->string('old_value')->nullable();
            $table->string('new_value')->nullable();
            $table->text('details')->nullable();
            $table->timestamp('created_at')->useCurrent();

            $table->index(['ticket_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ticket_logs');
        Schema::dropIfExists('ticket_notes');
        Schema::dropIfExists('ticket_tag');
        Schema::dropIfExists('tickets');
        Schema::dropIfExists('tags');
        Schema::dropIfExists('students');
        Schema::dropIfExists('guardians');
    }
};
