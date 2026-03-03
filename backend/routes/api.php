<?php

declare(strict_types=1);

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\TicketController;
use App\Http\Controllers\Api\GuardianController;
use App\Http\Controllers\Api\StudentController;
use App\Http\Controllers\Api\TeacherController;
use App\Http\Controllers\Api\AdminController;
use App\Http\Controllers\Api\ScheduleController;
use App\Http\Controllers\Api\SessionController;
use App\Http\Controllers\Api\ReminderController;
use App\Http\Controllers\Webhook\WhatsAppWebhookController;

/*
|--------------------------------------------------------------------------
| API Routes — Academy WhatsApp Communication System
|--------------------------------------------------------------------------
*/

// ── Webhooks (No Auth, signature-verified) ────────────────
Route::prefix('webhooks/whatsapp')->group(function () {
    Route::get('verify', [WhatsAppWebhookController::class, 'verify']);
    Route::post('/', [WhatsAppWebhookController::class, 'receive'])
        ->middleware(['webhook.signature', 'idempotency']);
    Route::post('status', [WhatsAppWebhookController::class, 'status'])
        ->middleware('webhook.signature');
});

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
        Route::get('{ticket}', [TicketController::class, 'show']);
        Route::post('{ticket}/reply', [TicketController::class, 'reply'])
            ->middleware('permission:tickets.reply');
        Route::put('{ticket}/assign', [TicketController::class, 'assign'])
            ->middleware('permission:tickets.assign');
        Route::put('{ticket}/status', [TicketController::class, 'updateStatus'])
            ->middleware('permission:tickets.resolve');
        Route::put('{ticket}/escalate', [TicketController::class, 'escalate'])
            ->middleware('permission:tickets.escalate');
        Route::post('{ticket}/note', [TicketController::class, 'addNote'])
            ->middleware('permission:tickets.reply');
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
        // Users
        Route::get('users', [AdminController::class, 'listUsers'])
            ->middleware('permission:users.view');
        Route::get('users/{id}', [AdminController::class, 'showUser'])
            ->middleware('permission:users.view');
        Route::post('users', [AdminController::class, 'createUser'])
            ->middleware('permission:users.create');
        Route::put('users/{id}', [AdminController::class, 'updateUser'])
            ->middleware('permission:users.edit');
        Route::delete('users/{id}', [AdminController::class, 'deleteUser'])
            ->middleware('permission:users.delete');

        // Analytics
        Route::get('analytics', [AdminController::class, 'analytics'])
            ->middleware('permission:analytics.view');

        // Audit Log
        Route::get('audit-log', [AdminController::class, 'auditLog'])
            ->middleware('permission:audit.view');
    });
});
