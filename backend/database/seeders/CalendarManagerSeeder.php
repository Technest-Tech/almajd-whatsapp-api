<?php

declare(strict_types=1);

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use Spatie\Permission\Models\Role;

class CalendarManagerSeeder extends Seeder
{
    public function run(): void
    {
        // Ensure the calendar_manager role exists
        $role = Role::firstOrCreate([
            'name'       => 'calendar_manager',
            'guard_name' => 'api',
        ]);

        // Create (or retrieve) the calendar manager user — idempotent
        $user = User::firstOrCreate(
            ['email' => 'calendar@almajd.academy'],
            [
                'name'     => 'مدير التقويم',
                'phone'    => '+966500000099',
                'password' => bcrypt('Calendar@2025'),
            ]
        );

        // Assign the role (safe to call multiple times)
        if (!$user->hasRole('calendar_manager')) {
            $user->assignRole($role);
        }

        $this->command->info('✅ Calendar Manager account seeded: calendar@almajd.academy');
    }
}
