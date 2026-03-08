<?php

declare(strict_types=1);

namespace App\Services\WhatsApp;

interface WhatsAppServiceInterface
{
    /**
     * Send a free-form text message (within 24h session window).
     *
     * @return array{message_id: string, status: string}
     */
    public function sendText(string $to, string $message, ?string $idempotencyKey = null, ?string $replyToMessageSid = null): array;

    /**
     * Send an approved template message (works outside session window).
     *
     * @param array<string, string> $params Template variables
     * @return array{message_id: string, status: string}
     */
    public function sendTemplate(string $to, string $templateName, array $params, string $language = 'ar'): array;

    /**
     * Send a media message (image, document, audio, video).
     *
     * @return array{message_id: string, status: string}
     */
    public function sendMedia(string $to, string $mediaUrl, string $type, ?string $caption = null, ?string $replyToMessageSid = null): array;

    /**
     * Check if the phone number is within the 24-hour session window.
     * (Last inbound message within 24 hours.)
     */
    public function isWithinSessionWindow(string $phoneNumber): bool;
}
