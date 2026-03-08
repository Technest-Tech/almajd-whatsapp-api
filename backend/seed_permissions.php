<?php
require __DIR__.'/vendor/autoload.php';
$app = require_once __DIR__.'/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use Spatie\Permission\Models\Role;
use Spatie\Permission\Models\Permission;

$modules = ['students', 'tickets', 'sessions', 'timetables', 'schedules', 'reminders', 'teachers'];
$actions = ['view', 'create', 'update', 'delete'];

try {
    foreach ($modules as $module) {
        foreach ($actions as $action) {
            Permission::firstOrCreate(['name' => "{$module}.{$action}", 'guard_name' => 'api']);
            Permission::firstOrCreate(['name' => "{$module}.{$action}", 'guard_name' => 'web']);
        }
    }

    $admin = Role::firstOrCreate(['name' => 'admin']);
    $admin->syncPermissions(Permission::all());

    echo "Permissions seeded and assigned to admin role.\n";
} catch (\Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
