<?php
require __DIR__.'/vendor/autoload.php';
$app = require_once __DIR__.'/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

$user = \App\Models\User::where('email', 'admin@almajd.com')->first();
if ($user) {
    echo "User exists.\n";
    echo "Password hash: " . $user->password . "\n";
    echo "Check password: " . (password_verify('Admin@2026', $user->password) ? 'true' : 'false') . "\n";
} else {
    echo "User does NOT exist.\n";
}
