<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        // 1. Seed roles and permissions first
        $this->call(RolesAndPermissionsSeeder::class);

        // 2. Create default admin user
        $admin = User::factory()->create([
            'name'     => 'Admin',
            'email'    => 'admin@almajd.academy',
            'phone'    => '+966500000000',
            'password' => bcrypt('password'),
        ]);
        $admin->assignRole('admin');

        // 3. Create a test supervisor
        $supervisor = User::factory()->create([
            'name'     => 'Supervisor',
            'email'    => 'supervisor@almajd.academy',
            'phone'    => '+966500000001',
            'password' => bcrypt('password'),
        ]);
        $supervisor->assignRole('supervisor');
    }
}
