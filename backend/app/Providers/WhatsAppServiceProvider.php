<?php

declare(strict_types=1);

namespace App\Providers;

use App\Services\WhatsApp\TwilioWhatsAppService;
use App\Services\WhatsApp\WhatsAppServiceInterface;
use Illuminate\Support\ServiceProvider;

class WhatsAppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->singleton(WhatsAppServiceInterface::class, function ($app) {
            $provider = config('whatsapp.provider', 'twilio');

            return match ($provider) {
                'twilio' => new TwilioWhatsAppService(),
                // '360dialog' => new Dialog360WhatsAppService(),
                default => throw new \InvalidArgumentException("Unsupported WhatsApp provider: {$provider}"),
            };
        });
    }

    public function boot(): void
    {
        //
    }
}
