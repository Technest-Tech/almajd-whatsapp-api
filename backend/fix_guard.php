<?php
require __DIR__.'/vendor/autoload.php';
$app = require_once __DIR__.'/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

try {
    $role = \Spatie\Permission\Models\Role::where('name', 'admin')->first();
    if ($role) {
        $role->guard_name = 'api';
        $role->save();
        echo "Role guard_name updated to 'api'.\n";
    } else {
        echo "Role not found.\n";
    }

    $permissions = \Spatie\Permission\Models\Permission::where('guard_name', 'api')->get();
    $role->syncPermissions($permissions);
    echo "Permissions synced with 'api' guard.\n";

    // Clear spatie cache
    app()[\Spatie\Permission\PermissionRegistrar::class]->forgetCachedPermissions();
    echo "Spatie cache cleared.\n";
} catch (\Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
