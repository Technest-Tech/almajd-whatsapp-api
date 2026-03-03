<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Models\Guardian;
use App\Models\Student;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CrudTest extends TestCase
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

    // ── Guardians ──────────────────────────────────────

    public function test_create_guardian(): void
    {
        $response = $this->actingAs($this->admin, 'api')
            ->postJson('/api/guardians', [
                'name'  => 'Ahmad Ali',
                'phone' => '+966501234567',
                'email' => 'ahmad@example.com',
            ]);

        $response->assertStatus(201);
        $this->assertDatabaseHas('guardians', ['phone' => '+966501234567']);
    }

    public function test_list_guardians(): void
    {
        Guardian::create(['name' => 'Test', 'phone' => '+966500000001']);
        Guardian::create(['name' => 'Test2', 'phone' => '+966500000002']);

        $response = $this->actingAs($this->admin, 'api')
            ->getJson('/api/guardians');

        $response->assertOk()
            ->assertJsonCount(2, 'data');
    }

    // ── Students ───────────────────────────────────────

    public function test_create_student(): void
    {
        $guardian = Guardian::create(['name' => 'Parent', 'phone' => '+966501234567']);

        $response = $this->actingAs($this->admin, 'api')
            ->postJson('/api/students', [
                'name'        => 'Mohammed',
                'guardian_id' => $guardian->id,
            ]);

        $response->assertStatus(201);
        $this->assertDatabaseHas('students', ['name' => 'Mohammed']);
    }

    public function test_update_student(): void
    {
        $student = Student::create(['name' => 'Old Name']);

        $response = $this->actingAs($this->admin, 'api')
            ->putJson("/api/students/{$student->id}", [
                'name' => 'New Name',
            ]);

        $response->assertOk();
        $this->assertDatabaseHas('students', ['id' => $student->id, 'name' => 'New Name']);
    }

    public function test_delete_student(): void
    {
        $student = Student::create(['name' => 'To Delete']);

        $response = $this->actingAs($this->admin, 'api')
            ->deleteJson("/api/students/{$student->id}");

        $response->assertOk();
        $this->assertSoftDeleted('students', ['id' => $student->id]);
    }

    // ── Teachers ───────────────────────────────────────

    public function test_create_teacher(): void
    {
        $response = $this->actingAs($this->admin, 'api')
            ->postJson('/api/teachers', [
                'name'  => 'Teacher Name',
                'phone' => '+966509876543',
            ]);

        $response->assertStatus(201);
        $this->assertDatabaseHas('teachers', ['name' => 'Teacher Name']);
    }

    public function test_supervisor_cannot_create_teacher(): void
    {
        $supervisor = User::factory()->create();
        $supervisor->assignRole('supervisor');

        $response = $this->actingAs($supervisor, 'api')
            ->postJson('/api/teachers', [
                'name' => 'Should Fail',
            ]);

        $response->assertStatus(403);
    }
}
