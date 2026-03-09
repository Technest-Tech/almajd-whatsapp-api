<?php

declare(strict_types=1);

namespace App\Services;

use Kreait\Firebase\Factory;
use Kreait\Firebase\Messaging\CloudMessage;
use Kreait\Firebase\Messaging\Notification;
use Kreait\Firebase\Exception\MessagingException;
use Illuminate\Support\Facades\Log;

class FcmService
{
    private static ?FcmService $_instance = null;
    private readonly \Kreait\Firebase\Contract\Messaging $messaging;

    public function __construct()
    {
        $keyPath = base_path('firebase-service-account.json');

        $factory = (new Factory())->withServiceAccount($keyPath);
        $this->messaging = $factory->createMessaging();
    }

    public static function getInstance(): self
    {
        if (self::$_instance === null) {
            self::$_instance = new self();
        }
        return self::$_instance;
    }

    /**
     * Send a FCM push notification to a single device token.
     */
    public function sendToToken(
        string $fcmToken,
        string $title,
        string $body,
        array $data = [],
    ): bool {
        try {
            $message = CloudMessage::withTarget('token', $fcmToken)
                ->withNotification(Notification::create($title, $body))
                ->withData(array_map('strval', $data));

            $this->messaging->send($message);
            return true;
        } catch (MessagingException $e) {
            Log::warning('FCM send failed', [
                'token' => substr($fcmToken, 0, 10) . '...',
                'error' => $e->getMessage(),
            ]);
            return false;
        }
    }

    /**
     * Send to all stored FCM tokens for a given user.
     */
    public function sendToUser(
        int $userId,
        string $title,
        string $body,
        array $data = [],
    ): void {
        $tokens = \App\Models\DeviceSession::where('user_id', $userId)
            ->whereNotNull('fcm_token')
            ->pluck('fcm_token')
            ->unique()
            ->values();

        foreach ($tokens as $token) {
            $this->sendToToken($token, $title, $body, $data);
        }
    }

    /**
     * Send to all admin users.
     */
    public function sendToAllAdmins(string $title, string $body, array $data = []): void
    {
        $adminIds = \App\Models\User::all()->pluck('id');

        foreach ($adminIds as $userId) {
            $this->sendToUser($userId, $title, $body, $data);
        }
    }
}
