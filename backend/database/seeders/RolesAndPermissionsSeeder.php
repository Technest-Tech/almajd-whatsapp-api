<?php

declare(strict_types=1);

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;

class RolesAndPermissionsSeeder extends Seeder
{
    public function run(): void
    {
        // Reset cached roles and permissions
        app()[\Spatie\Permission\PermissionRegistrar::class]->forgetCachedPermissions();

        // ── Permissions ──────────────────────────────────
        $permissions = [
            // Tickets
            'tickets.view', 'tickets.create', 'tickets.reply', 'tickets.assign',
            'tickets.escalate', 'tickets.resolve', 'tickets.close',
            // Students
            'students.view', 'students.create', 'students.edit', 'students.delete',
            // Teachers
            'teachers.view', 'teachers.create', 'teachers.edit', 'teachers.delete',
            // Schedules
            'schedules.view', 'schedules.create', 'schedules.edit', 'schedules.delete',
            // Sessions
            'sessions.view', 'sessions.edit',
            // Reminders
            'reminders.view', 'reminders.manage',
            // Templates
            'templates.view', 'templates.manage',
            // Users (Admin)
            'users.view', 'users.create', 'users.edit', 'users.delete',
            // Admin features
            'routing.manage', 'sla.manage', 'analytics.view', 'audit.view',
            // Calendar (Legacy System)
            'calendar.view', 'calendar.manage',
        ];

        foreach ($permissions as $perm) {
            Permission::firstOrCreate(['name' => $perm, 'guard_name' => 'api']);
        }

        // ── Roles ────────────────────────────────────────
        $supervisor      = Role::firstOrCreate(['name' => 'supervisor',        'guard_name' => 'api']);
        $senior          = Role::firstOrCreate(['name' => 'senior_supervisor',  'guard_name' => 'api']);
        $admin           = Role::firstOrCreate(['name' => 'admin',              'guard_name' => 'api']);
        $calendarManager = Role::firstOrCreate(['name' => 'calendar_manager',   'guard_name' => 'api']);

        // ── Assign Permissions ───────────────────────────
        // Supervisor: tickets, view+edit students & schedules & sessions, view reminders
        $supervisor->syncPermissions([
            'tickets.view', 'tickets.create', 'tickets.reply', 'tickets.assign',
            'tickets.escalate', 'tickets.resolve', 'tickets.close',
            'students.view',
            'schedules.view',
            'schedules.edit',   // needed for reschedule / cancel / complete session routes
            'sessions.view',
            'sessions.edit',
            'reminders.view',
            // Teachers
            'teachers.view', 'teachers.create', 'teachers.edit', 'teachers.delete',
        ]);

        // Senior Supervisor: everything supervisor has + analytics, users view
        $senior->syncPermissions([
            'tickets.view', 'tickets.create', 'tickets.reply', 'tickets.assign',
            'tickets.escalate', 'tickets.resolve', 'tickets.close',
            'students.view',
            'schedules.view',
            'sessions.view',
            'sessions.edit',
            // Teachers features
            'teachers.view', 'teachers.create', 'teachers.edit', 'teachers.delete',
            'analytics.view',
            'users.view',
        ]);

        // Admin: ALL permissions
        $admin->syncPermissions($permissions);

        // Calendar Manager: calendar-only access
        $calendarManager->syncPermissions([
            'calendar.view',
            'calendar.manage',
        ]);
    }
}
