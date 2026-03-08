<?php
$user = \App\Models\User::where('email', 'admin@almajd.com')->first();
if ($user) {
    $user->password = bcrypt('Admin@2026');
    $user->save();
    echo "Password updated successfully.\n";
} else {
    echo "User not found.\n";
}
