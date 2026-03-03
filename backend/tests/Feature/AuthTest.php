<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuthTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->artisan('db:seed', ['--class' => 'Database\\Seeders\\RolesAndPermissionsSeeder']);
    }

    public function test_login_with_valid_credentials(): void
    {
        $user = User::factory()->create(['password' => bcrypt('password123')]);
        $user->assignRole('supervisor');

        $response = $this->postJson('/api/auth/login', [
            'email'       => $user->email,
            'password'    => 'password123',
            'device_id'   => 'test-device-001',
            'device_name' => 'PHPUnit',
        ]);

        $response->assertOk()
            ->assertJsonStructure([
                'success',
                'data' => ['access_token', 'refresh_token', 'token_type', 'user'],
            ]);
    }

    public function test_login_with_invalid_credentials(): void
    {
        $response = $this->postJson('/api/auth/login', [
            'email'       => 'nonexistent@test.com',
            'password'    => 'wrong',
            'device_id'   => 'test-device-001',
            'device_name' => 'PHPUnit',
        ]);

        $response->assertStatus(401);
    }

    public function test_me_requires_auth(): void
    {
        $response = $this->getJson('/api/auth/me');
        $response->assertStatus(401);
    }

    public function test_me_returns_user_profile(): void
    {
        $user = User::factory()->create();
        $user->assignRole('admin');

        $response = $this->actingAs($user, 'api')
            ->getJson('/api/auth/me');

        $response->assertOk()
            ->assertJsonPath('data.email', $user->email);
    }

    public function test_update_availability(): void
    {
        $user = User::factory()->create();
        $user->assignRole('supervisor');

        $response = $this->actingAs($user, 'api')
            ->putJson('/api/auth/me/availability', [
                'availability' => 'busy',
            ]);

        $response->assertOk();
        $this->assertDatabaseHas('users', [
            'id'           => $user->id,
            'availability' => 'busy',
        ]);
    }
}
