<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Models\Guardian;
use App\Models\Ticket;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class TicketTest extends TestCase
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

    public function test_list_tickets_requires_permission(): void
    {
        $user = User::factory()->create();
        // No role assigned — should fail

        $response = $this->actingAs($user, 'api')
            ->getJson('/api/tickets');

        $response->assertStatus(403);
    }

    public function test_list_tickets_as_admin(): void
    {
        $response = $this->actingAs($this->admin, 'api')
            ->getJson('/api/tickets');

        $response->assertOk()
            ->assertJsonStructure(['success', 'data', 'pagination']);
    }

    public function test_show_ticket(): void
    {
        $guardian = Guardian::create(['name' => 'Test Parent', 'phone' => '+966501234567']);
        $ticket = Ticket::create([
            'ticket_number' => Ticket::generateTicketNumber(),
            'guardian_id'   => $guardian->id,
            'status'        => 'open',
            'priority'      => 'normal',
            'channel'       => 'whatsapp',
        ]);

        $response = $this->actingAs($this->admin, 'api')
            ->getJson("/api/tickets/{$ticket->id}");

        $response->assertOk()
            ->assertJsonPath('data.ticket_number', $ticket->ticket_number);
    }

    public function test_assign_ticket(): void
    {
        $supervisor = User::factory()->create();
        $supervisor->assignRole('supervisor');

        $ticket = Ticket::create([
            'ticket_number' => Ticket::generateTicketNumber(),
            'status'        => 'open',
            'priority'      => 'normal',
        ]);

        $response = $this->actingAs($this->admin, 'api')
            ->putJson("/api/tickets/{$ticket->id}/assign", [
                'user_id' => $supervisor->id,
            ]);

        $response->assertOk();
        $this->assertDatabaseHas('tickets', [
            'id'          => $ticket->id,
            'assigned_to' => $supervisor->id,
        ]);
    }

    public function test_update_ticket_status(): void
    {
        $ticket = Ticket::create([
            'ticket_number' => Ticket::generateTicketNumber(),
            'status'        => 'open',
            'priority'      => 'normal',
        ]);

        $response = $this->actingAs($this->admin, 'api')
            ->putJson("/api/tickets/{$ticket->id}/status", [
                'status' => 'resolved',
            ]);

        $response->assertOk();
        $this->assertDatabaseHas('tickets', [
            'id'     => $ticket->id,
            'status' => 'resolved',
        ]);
    }

    public function test_ticket_stats(): void
    {
        $response = $this->actingAs($this->admin, 'api')
            ->getJson('/api/tickets/stats');

        $response->assertOk()
            ->assertJsonStructure([
                'data' => ['open', 'pending', 'resolved', 'sla_breached', 'today_total'],
            ]);
    }

    public function test_escalate_ticket(): void
    {
        $ticket = Ticket::create([
            'ticket_number' => Ticket::generateTicketNumber(),
            'status'        => 'open',
            'priority'      => 'normal',
        ]);

        $response = $this->actingAs($this->admin, 'api')
            ->putJson("/api/tickets/{$ticket->id}/escalate", [
                'reason' => 'Parent is very upset',
            ]);

        $response->assertOk();
        $this->assertDatabaseHas('tickets', [
            'id'               => $ticket->id,
            'escalation_level' => 1,
            'priority'         => 'urgent',
        ]);
    }

    public function test_add_note_to_ticket(): void
    {
        $ticket = Ticket::create([
            'ticket_number' => Ticket::generateTicketNumber(),
            'status'        => 'open',
            'priority'      => 'normal',
        ]);

        $response = $this->actingAs($this->admin, 'api')
            ->postJson("/api/tickets/{$ticket->id}/note", [
                'content' => 'Internal observation about this ticket',
            ]);

        $response->assertStatus(201);
        $this->assertDatabaseHas('ticket_notes', [
            'ticket_id' => $ticket->id,
            'content'   => 'Internal observation about this ticket',
        ]);
    }
}
