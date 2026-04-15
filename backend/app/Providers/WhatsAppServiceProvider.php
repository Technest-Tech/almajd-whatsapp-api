<?php

declare(strict_types=1);

namespace App\Providers;

use App\Services\WhatsApp\TwilioWhatsAppService;
use App\Services\WhatsApp\WasenderWhatsAppService;
use App\Services\WhatsApp\WhatsAppServiceInterface;
use Illuminate\Support\ServiceProvider;

class WhatsAppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->singleton(WhatsAppServiceInterface::class, function ($app) {
            $provider = config('whatsapp.provider', 'twilio');

            return match ($provider) {
                'twilio'   => new TwilioWhatsAppService(),
                'wasender' => new WasenderWhatsAppService(),
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
