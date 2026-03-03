<?php

declare(strict_types=1);

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class WebhookTest extends TestCase
{
    use RefreshDatabase;

    public function test_verify_endpoint_with_valid_token(): void
    {
        config(['whatsapp.verify_token' => 'test-verify-token']);

        $response = $this->get('/api/webhooks/whatsapp/verify?' . http_build_query([
            'hub_mode'         => 'subscribe',
            'hub_verify_token' => 'test-verify-token',
            'hub_challenge'    => 'challenge-12345',
        ]));

        $response->assertOk()
            ->assertSee('challenge-12345');
    }

    public function test_verify_endpoint_with_invalid_token(): void
    {
        config(['whatsapp.verify_token' => 'test-verify-token']);

        $response = $this->get('/api/webhooks/whatsapp/verify?' . http_build_query([
            'hub_mode'         => 'subscribe',
            'hub_verify_token' => 'wrong-token',
            'hub_challenge'    => 'challenge-12345',
        ]));

        $response->assertStatus(403);
    }
}
