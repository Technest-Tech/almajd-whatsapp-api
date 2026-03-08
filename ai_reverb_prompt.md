# WebSocket Debugging Task

You are an expert AI developer tasked with fixing a critical WebSocket real-time messaging issue between a Flutter mobile app and a Laravel backend. 

## 1. Server & Environment Details
- **SSH Connection**: `root@64.225.63.111`
- **Project Path**: `/var/www/almajd/backend/`
- **Domain**: `cloud.almajd.info`
- **Tech Stack Backend**: Laravel 12, PHP 8.2, Laravel Reverb (WebSocket server), Nginx, Supervisor.
- **Tech Stack Frontend**: Flutter 3.24.3, dart_pusher_channels.

## 2. The Core Issue
Real-time chat messages are not syncing. When a user sends a message from the Flutter App, or when a Twilio Webhook receives an inbound message, the backend processes it successfully and saves it to the database, but it **fails to broadcast to the WebSockets**. 

When we check the backend Laravel error logs (`tail -n 50 storage/logs/laravel.log`), we see the following fatal exception triggered inside the Queue Worker during the `TicketMessageCreated` broadcast event:

```
[object] (TypeError(code: 0): Pusher\Pusher::__construct(): Argument #1 ($auth_key) must be of type string, null given, called in /var/www/almajd/backend/vendor/laravel/framework/src/Illuminate/Broadcasting/BroadcastManager.php on line 353 at /var/www/almajd/backend/vendor/pusher/pusher-php-server/src/Pusher.php:63)
[stacktrace]
#0 /var/www/almajd/backend/vendor/laravel/framework/src/Illuminate/Broadcasting/BroadcastManager.php(353): Pusher\Pusher->__construct()
#1 /var/www/almajd/backend/vendor/laravel/framework/src/Illuminate/Broadcasting/BroadcastManager.php(331): Illuminate\Broadcasting\BroadcastManager->pusher()
#2 /var/www/almajd/backend/vendor/laravel/framework/src/Illuminate/Broadcasting/BroadcastManager.php(320): Illuminate\Broadcasting\BroadcastManager->createPusherDriver()
#3 /var/www/almajd/backend/vendor/laravel/framework/src/Illuminate/Broadcasting/BroadcastManager.php(295): Illuminate\Broadcasting\BroadcastManager->createReverbDriver()
#4 /var/www/almajd/backend/vendor/laravel/framework/src/Illuminate/Broadcasting/BroadcastManager.php(265): Illuminate\Broadcasting\BroadcastManager->resolve()
#5 /var/www/almajd/backend/vendor/laravel/framework/src/Illuminate/Broadcasting/BroadcastManager.php(254): Illuminate\Broadcasting\BroadcastManager->get()
#6 /var/www/almajd/backend/vendor/laravel/framework/src/Illuminate/Broadcasting/BroadcastManager.php(241): Illuminate\Broadcasting\BroadcastManager->driver()
```

This error indicates that when Laravel attempts to broadcast the event, its `BroadcastManager` is missing the `key` configuration, passing `null` to the underlying Pusher driver, which causes a fatal crash.

## 3. What Has Already Been Configured / Verified
You do not need to waste time on these, as they are already set up:
- **Supervisor Daemons**: Both `php artisan queue:work` (`almajd-worker`) and `php artisan reverb:start` (`almajd-reverb`) are actively running via Supervisor.
- **Nginx Proxy**: Nginx is successfully configured to proxy `/app` and `/apps` traffic via WSS on port 443 to Reverb's internal port `8080`.
- **Flutter Client**: The mobile app successfully connects to `cloud.almajd.info:443` using the `dart_pusher_channels` package, authenticating via `/api/broadcasting/auth`, and subscribes to `private-ticket.{id}`.
- **Backend .env**: We have injected the following keys into the `/var/www/almajd/backend/.env` file:
  - `BROADCAST_CONNECTION=reverb`
  - `REVERB_APP_ID=almajd_app_id`
  - `REVERB_APP_KEY=almajd_app_key`
  - `REVERB_APP_SECRET=almajd_app_secret`
  - `REVERB_SERVER_PORT=8080`
  - `REVERB_PORT=443`
  - `VITE_REVERB_PORT=443`

## 4. Your Objective
Your goal is to SSH into the server and fix the `null $auth_key` crash in Laravel so WebSockets successfully dispatch without crashing the queue driver. 
Suspected root causes to check:
1. Is Laravel 12's core `config/broadcasting.php` properly mapping `REVERB_APP_KEY`? (Note: `config/broadcasting.php` was not directly published in the project root, so Laravel is using its internal framework defaults. You may need to publish it via `php artisan config:publish broadcasting` to explicitly map the `.env` keys).
2. Are the Supervisor queue workers (`almajd-worker`) hanging onto a stale, cached version of the `.env` from before the keys were injected? Hard-restart them.
3. Is `PUSHER_APP_KEY` unexpectedly required by the Laravel Broadcast manager even if the driver is set to `reverb`?

Please identify the configuration breakdown, apply the fix, restart all cached configurations and supervisor daemons, and verify that the Flutter App receives WebSocket events.
