<?php
$user = \App\Models\User::firstOrCreate(
    ['email' => 'admin@almajd.com'],
    ['name' => 'أحمد المشرف', 'password' => bcrypt('Admin@2026')]
);
$user->assignRole('admin');
echo "Admin seeded successfully.\n";
