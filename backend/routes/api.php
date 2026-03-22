<?php

declare(strict_types=1);

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\TicketController;
use App\Http\Controllers\Api\TicketMediaController;
use App\Http\Controllers\Api\GuardianController;
use App\Http\Controllers\Api\StudentController;
use App\Http\Controllers\Api\TeacherController;
use App\Http\Controllers\Api\AdminController;
use App\Http\Controllers\Api\ScheduleController;
use App\Http\Controllers\Api\SessionController;
use App\Http\Controllers\Api\ReminderController;
use App\Http\Controllers\Api\TemplateController;
use App\Http\Controllers\Api\NotificationController;
use App\Http\Controllers\Webhook\WhatsAppWebhookController;
use App\Http\Controllers\Webhook\TwilioWebhookController;

/*
|--------------------------------------------------------------------------
| API Routes — Academy WhatsApp Communication System
|--------------------------------------------------------------------------
*/

// ── Twilio Webhooks (No Auth, SDK signature-verified) ────────
Route::prefix('webhooks/twilio/whatsapp')->group(function () {
    Route::post('/', [TwilioWebhookController::class, 'receive'])
        ->middleware(['twilio.signature', 'idempotency']);
        
    Route::post('status', [TwilioWebhookController::class, 'status'])
        ->middleware('twilio.signature');
});

// ── Meta Webhooks (Legacy fallback) ──────────────────────────
Route::prefix('webhooks/whatsapp')->group(function () {
    Route::get('verify', [WhatsAppWebhookController::class, 'verify']);
    Route::post('/', [WhatsAppWebhookController::class, 'receive'])
        ->middleware(['webhook.signature', 'idempotency']);
    Route::post('status', [WhatsAppWebhookController::class, 'status'])
        ->middleware('webhook.signature');
});

// ── Public Media ──────────────────────────────────────────
Route::get('media/tickets/{ticket}/{filename}', [TicketMediaController::class, 'download'])
    ->name('ticket.media.download');

// ── Public Auth ───────────────────────────────────────────
Route::prefix('auth')->group(function () {
    Route::post('login', [AuthController::class, 'login']);
    Route::post('refresh', [AuthController::class, 'refresh']);
});

// ── Protected (JWT Auth) ──────────────────────────────────
Route::middleware('auth:api')->group(function () {

    // Auth (self)
    Route::prefix('auth')->group(function () {
        Route::post('logout', [AuthController::class, 'logout']);
        Route::get('me', [AuthController::class, 'me']);
        Route::put('me/availability', [AuthController::class, 'updateAvailability']);
    });

    // ── Tickets ─────────────────────────────────────────
    Route::prefix('tickets')->middleware('permission:tickets.view')->group(function () {
        Route::get('/', [TicketController::class, 'index']);
        Route::get('stats', [TicketController::class, 'stats']);
        Route::get('unread-count', [TicketController::class, 'unreadCount'])
            ->middleware('permission:tickets.view');
        Route::post('create-for-student', [TicketController::class, 'createForStudent'])
            ->middleware('permission:tickets.create');
        Route::post('create-for-contact', [TicketController::class, 'createForContact'])
            ->middleware('permission:tickets.create');
        Route::get('{ticket}', [TicketController::class, 'show']);
        Route::post('{ticket}/reply', [TicketController::class, 'reply'])
            ->middleware('permission:tickets.reply');
        Route::post('{ticket}/send-template', [TicketController::class, 'sendTemplate'])
            ->middleware('permission:tickets.reply');
        Route::put('{ticket}/assign', [TicketController::class, 'assign'])
            ->middleware('permission:tickets.assign');
        Route::put('{ticket}/status', [TicketController::class, 'updateStatus'])
            ->middleware('permission:tickets.resolve');
        Route::put('{ticket}/escalate', [TicketController::class, 'escalate'])
            ->middleware('permission:tickets.escalate');
        Route::post('{ticket}/note', [TicketController::class, 'addNote'])
            ->middleware('permission:tickets.reply');
        Route::post('{ticket}/upload', [TicketMediaController::class, 'upload'])
            ->middleware('permission:tickets.reply');
        Route::delete('{ticket}', [TicketController::class, 'destroy'])
            ->middleware('permission:tickets.resolve');
        Route::post('{ticket}/read', [TicketController::class, 'markAsRead'])
            ->middleware('permission:tickets.reply');
        Route::get('{ticket}/messages', [TicketController::class, 'messages'])
            ->middleware('permission:tickets.view');
    });

    // ── Notifications ──────────────────────────────────
    Route::prefix('notifications')->group(function () {
        Route::get('/', [NotificationController::class, 'index']);
        Route::get('unread-count', [NotificationController::class, 'unreadCount']);
        Route::post('{id}/read', [NotificationController::class, 'markAsRead']);
        Route::post('read-all', [NotificationController::class, 'markAllAsRead']);
    });

    // ── WhatsApp Templates ──────────────────────────────
    Route::prefix('templates')->group(function () {
        Route::get('/', [TemplateController::class, 'index'])
            ->middleware('permission:templates.view');
        Route::get('approved', [TemplateController::class, 'approved'])
            ->middleware('permission:tickets.reply');
        Route::post('/', [TemplateController::class, 'store'])
            ->middleware('permission:templates.manage');
        Route::post('{id}/submit', [TemplateController::class, 'submit'])
            ->middleware('permission:templates.manage');
        Route::post('sync', [TemplateController::class, 'sync'])
            ->middleware('permission:templates.manage');
        Route::delete('{id}', [TemplateController::class, 'destroy'])
            ->middleware('permission:templates.manage');
    });

    // ── Guardians ───────────────────────────────────────
    Route::prefix('guardians')->group(function () {
        Route::get('/', [GuardianController::class, 'index']);
        Route::get('{id}', [GuardianController::class, 'show']);
        Route::post('/', [GuardianController::class, 'store'])
            ->middleware('permission:students.create');
        Route::put('{id}', [GuardianController::class, 'update'])
            ->middleware('permission:students.edit');
        Route::delete('{id}', [GuardianController::class, 'destroy'])
            ->middleware('permission:students.delete');
    });

    // ── Students ────────────────────────────────────────
    Route::prefix('students')->group(function () {
        Route::get('/', [StudentController::class, 'index'])
            ->middleware('permission:students.view');
        Route::get('{id}', [StudentController::class, 'show'])
            ->middleware('permission:students.view');
        Route::post('/', [StudentController::class, 'store'])
            ->middleware('permission:students.create');
        Route::put('{id}', [StudentController::class, 'update'])
            ->middleware('permission:students.edit');
        Route::delete('{id}', [StudentController::class, 'destroy'])
            ->middleware('permission:students.delete');

        // Per-student schedule entries
        Route::get('{id}/schedule-entries', [StudentController::class, 'scheduleEntries'])
            ->middleware('permission:students.view');
        Route::post('{id}/schedule-entries', [StudentController::class, 'storeScheduleEntry'])
            ->middleware('permission:schedules.create');
        Route::put('{id}/schedule-entries/{entryId}', [StudentController::class, 'updateScheduleEntry'])
            ->middleware('permission:schedules.edit');
        Route::delete('{id}/schedule-entries/{entryId}', [StudentController::class, 'destroyScheduleEntry'])
            ->middleware('permission:schedules.delete');

        // Per-student class sessions
        Route::get('{id}/class-sessions', [StudentController::class, 'classSessions'])
            ->middleware('permission:students.view');
        Route::post('{id}/class-sessions/generate', [StudentController::class, 'generateClassSessions'])
            ->middleware('permission:schedules.create');
        Route::put('{id}/class-sessions/{sessionId}/reschedule', [StudentController::class, 'rescheduleSession'])
            ->middleware('permission:schedules.edit');
        Route::put('{id}/class-sessions/{sessionId}/cancel', [StudentController::class, 'cancelSession'])
            ->middleware('permission:schedules.edit');
        Route::put('{id}/class-sessions/{sessionId}/complete', [StudentController::class, 'completeSession'])
            ->middleware('permission:schedules.edit');
    });

    // ── Teachers ────────────────────────────────────────
    Route::prefix('teachers')->group(function () {
        Route::get('/', [TeacherController::class, 'index'])
            ->middleware('permission:teachers.view');
        Route::get('{id}', [TeacherController::class, 'show'])
            ->middleware('permission:teachers.view');
        Route::post('/', [TeacherController::class, 'store'])
            ->middleware('permission:teachers.create');
        Route::put('{id}', [TeacherController::class, 'update'])
            ->middleware('permission:teachers.edit');
        Route::delete('{id}', [TeacherController::class, 'destroy'])
            ->middleware('permission:teachers.delete');
    });

    // ── Schedules ───────────────────────────────────────
    Route::prefix('schedules')->middleware('permission:schedules.view')->group(function () {
        Route::get('/', [ScheduleController::class, 'index']);
        Route::get('{id}', [ScheduleController::class, 'show']);
        Route::get('{id}/sessions', [ScheduleController::class, 'sessions']);
        Route::post('/', [ScheduleController::class, 'store'])
            ->middleware('permission:schedules.create');
        Route::put('{id}', [ScheduleController::class, 'update'])
            ->middleware('permission:schedules.edit');
        Route::delete('{id}', [ScheduleController::class, 'destroy'])
            ->middleware('permission:schedules.delete');

        // Nested entries
        Route::post('{scheduleId}/entries', [ScheduleController::class, 'addEntry'])
            ->middleware('permission:schedules.create');
        Route::put('{scheduleId}/entries/{entryId}', [ScheduleController::class, 'updateEntry'])
            ->middleware('permission:schedules.edit');
        Route::delete('{scheduleId}/entries/{entryId}', [ScheduleController::class, 'deleteEntry'])
            ->middleware('permission:schedules.delete');
    });

    // ── Sessions ────────────────────────────────────────
    Route::prefix('sessions')->middleware('permission:sessions.view')->group(function () {
        Route::get('/', [SessionController::class, 'index']);
        Route::get('{id}', [SessionController::class, 'show']);
        Route::put('{id}/status', [SessionController::class, 'updateStatus'])
            ->middleware('permission:sessions.edit');
        Route::post('{id}/remind', [SessionController::class, 'sendReminder'])
            ->middleware('permission:sessions.edit');
    });

    // ── Reminders ───────────────────────────────────────
    Route::prefix('reminders')->middleware('permission:reminders.view')->group(function () {
        Route::get('/', [ReminderController::class, 'index']);
        Route::post('/', [ReminderController::class, 'store'])
            ->middleware('permission:reminders.manage');
        Route::post('bulk', [ReminderController::class, 'bulkCreate'])
            ->middleware('permission:reminders.manage');
        Route::put('{id}/cancel', [ReminderController::class, 'cancel'])
            ->middleware('permission:reminders.manage');
    });

    // ── Admin ───────────────────────────────────────────
    Route::prefix('admin')->group(function () {
        // Supervisors
        Route::get('supervisors', [AdminController::class, 'listSupervisors'])
            ->middleware('permission:users.view');
        Route::get('supervisors/{id}', [AdminController::class, 'showSupervisor'])
            ->middleware('permission:users.view');
        Route::post('supervisors', [AdminController::class, 'createSupervisor'])
            ->middleware('permission:users.create');
        Route::put('supervisors/{id}', [AdminController::class, 'updateSupervisor'])
            ->middleware('permission:users.edit');
        Route::delete('supervisors/{id}', [AdminController::class, 'deleteSupervisor'])
            ->middleware('permission:users.delete');

        // Supervisor Performance
        Route::get('supervisors/performance', [\App\Http\Controllers\Api\SupervisorPerformanceController::class, 'index'])
            ->middleware('permission:users.view');
        Route::get('supervisors/{id}/performance', [\App\Http\Controllers\Api\SupervisorPerformanceController::class, 'show'])
            ->middleware('permission:users.view');
        Route::get('supervisors/{id}/performance/export', [\App\Http\Controllers\Api\SupervisorPerformanceController::class, 'export'])
            ->middleware('permission:users.view');

        // Analytics
        Route::get('analytics', [AdminController::class, 'analytics'])
            ->middleware('permission:analytics.view');

        // Audit Log
        Route::get('audit-log', [AdminController::class, 'auditLog'])
            ->middleware('permission:audit.view');
    });
});

Route::get('/wipe-schedules', function () {
    \App\Models\ClassSession::query()->delete();
    \App\Models\ScheduleEntry::query()->delete();
    \App\Models\Schedule::query()->delete();
    return response()->json(['message' => 'All schedules, entries and sessions have been wiped cleanly.']);
});
