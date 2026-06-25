<?php

declare(strict_types=1);

namespace App\Services\WhatsApp;

use App\Models\Setting;

/**
 * Resolves the currently-active Wasender session (API key + sender number).
 *
 * Two physical sessions are configured in config/whatsapp.php:
 *   - 'primary' → wasender.api_key / wasender.from_number      (e.g. 012)
 *   - 'old'     → wasender.old_api_key / wasender.old_from_number (e.g. 015)
 *
 * Exactly ONE is active at a time for session reminders + the inbox. The admin
 * picks it from the app; the choice is stored in the `settings` table under
 * `whatsapp_active_session`. Everything that sends to / receives from guardians
 * and teachers (reminders, polls, inbox replies) routes through the active
 * session. Teacher timetables + the daily self-summary stay pinned to the old
 * "015" session and do NOT consult this resolver (see CalendarController).
 */
final class WasenderSession
{
    public const SETTING_KEY = 'whatsapp_active_session';

    public const PRIMARY = 'primary';
    public const OLD     = 'old';

    /** @return 'primary'|'old' */
    public static function active(): string
    {
        $value = Setting::get(self::SETTING_KEY, self::PRIMARY);

        return $value === self::OLD ? self::OLD : self::PRIMARY;
    }

    /**
     * API key of the active session. Falls back to the primary session when
     * 'old' is selected but its key is not configured, so a misconfigured
     * switch can never silently disable sending.
     */
    public static function apiKey(): string
    {
        $primary = (string) config('whatsapp.wasender.api_key');

        return self::active() === self::OLD
            ? ((string) config('whatsapp.wasender.old_api_key') ?: $primary)
            : $primary;
    }

    /** Sender number (E.164) of the active session, with the same fallback. */
    public static function fromNumber(): string
    {
        $primary = (string) config('whatsapp.wasender.from_number');

        return self::active() === self::OLD
            ? ((string) config('whatsapp.wasender.old_from_number') ?: $primary)
            : $primary;
    }

    /**
     * The API key of the session that owns the given sender number, so a chat
     * always sends from its OWN number regardless of which session is active.
     * Falls back to the active session's key for unknown/empty numbers.
     */
    public static function apiKeyForNumber(?string $number): string
    {
        $digits = self::digits($number);
        if ($digits === '') {
            return self::apiKey();
        }

        if ($digits === self::digits((string) config('whatsapp.wasender.old_from_number'))) {
            return (string) config('whatsapp.wasender.old_api_key') ?: self::apiKey();
        }
        if ($digits === self::digits((string) config('whatsapp.wasender.from_number'))) {
            return (string) config('whatsapp.wasender.api_key');
        }

        return self::apiKey();
    }

    private static function digits(?string $value): string
    {
        return preg_replace('/\D/', '', (string) $value) ?? '';
    }

    /**
     * True when the given webhook sessionId belongs to the active session.
     *
     * Wasender stamps every webhook with a top-level `sessionId` equal to that
     * session's API key, so we can reject inbound that arrives on the dormant
     * number. Fail-open when sessionId is absent (older payloads).
     */
    public static function isActiveSessionId(?string $sessionId): bool
    {
        if ($sessionId === null || $sessionId === '') {
            return true;
        }

        return hash_equals(self::apiKey(), $sessionId);
    }
}
