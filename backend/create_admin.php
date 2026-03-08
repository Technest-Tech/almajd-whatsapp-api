<?php
require __DIR__.'/vendor/autoload.php';
$app = require_once __DIR__.'/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

try {
    $user = \App\Models\User::where('email', 'admin@almajd.com')->first();
    if (!$user) {
        $user = new \App\Models\User();
        $user->name = 'أحمد المشرف';
        $user->email = 'admin@almajd.com';
        $user->password = bcrypt('Admin@2026');
        $user->save();
        echo "User created.\n";
    } else {
        $user->password = bcrypt('Admin@2026');
        $user->save();
        echo "User password updated.\n";
    }

    $role = \Spatie\Permission\Models\Role::firstOrCreate(['name' => 'admin']);
    if (!$user->hasRole('admin')) {
        $user->assignRole('admin');
        echo "Assigned admin role.\n";
    } else {
        echo "Already has admin role.\n";
    }
} catch (\Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
