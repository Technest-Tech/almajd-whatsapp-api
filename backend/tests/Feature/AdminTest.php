<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AdminTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;

    protected function setUp(): void
    {
        parent::setUp();
        $this->artisan('db:seed', ['--class' => 'Database\\Seeders\\RolesAndPermissionsSeeder']);

        $this->admin = User::factory()->create();
        $this->admin->assignRole('admin');
    }

    public function test_list_users_requires_permission(): void
    {
        $supervisor = User::factory()->create();
        $supervisor->assignRole('supervisor');

        $response = $this->actingAs($supervisor, 'api')
            ->getJson('/api/admin/users');

        $response->assertStatus(403);
    }

    public function test_admin_can_list_users(): void
    {
        $response = $this->actingAs($this->admin, 'api')
            ->getJson('/api/admin/users');

        $response->assertOk()
            ->assertJsonStructure(['success', 'data', 'pagination']);
    }

    public function test_admin_can_create_user(): void
    {
        $response = $this->actingAs($this->admin, 'api')
            ->postJson('/api/admin/users', [
                'name'     => 'New Supervisor',
                'email'    => 'new-supervisor@test.com',
                'password' => 'SecurePass123',
                'role'     => 'supervisor',
            ]);

        $response->assertStatus(201);
        $this->assertDatabaseHas('users', ['email' => 'new-supervisor@test.com']);
    }

    public function test_admin_can_update_user(): void
    {
        $user = User::factory()->create();
        $user->assignRole('supervisor');

        $response = $this->actingAs($this->admin, 'api')
            ->putJson("/api/admin/users/{$user->id}", [
                'name'             => 'Updated Name',
                'max_open_tickets' => 15,
            ]);

        $response->assertOk();
        $this->assertDatabaseHas('users', [
            'id'               => $user->id,
            'name'             => 'Updated Name',
            'max_open_tickets' => 15,
        ]);
    }

    public function test_admin_can_deactivate_user(): void
    {
        $user = User::factory()->create();
        $user->assignRole('supervisor');

        $response = $this->actingAs($this->admin, 'api')
            ->deleteJson("/api/admin/users/{$user->id}");

        $response->assertOk();
        $this->assertSoftDeleted('users', ['id' => $user->id]);
    }

    public function test_analytics_endpoint(): void
    {
        $response = $this->actingAs($this->admin, 'api')
            ->getJson('/api/admin/analytics');

        $response->assertOk()
            ->assertJsonStructure([
                'data' => [
                    'overview' => ['total_tickets', 'resolved_tickets', 'open_tickets', 'sla_breached'],
                    'tickets_by_status',
                    'tickets_by_priority',
                    'daily_volume',
                    'supervisor_performance',
                    'sla_compliance',
                ],
            ]);
    }

    public function test_audit_log_endpoint(): void
    {
        $response = $this->actingAs($this->admin, 'api')
            ->getJson('/api/admin/audit-log');

        $response->assertOk()
            ->assertJsonStructure(['success', 'data', 'pagination']);
    }
}
