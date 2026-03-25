<?php

declare(strict_types=1);

namespace App\Support;

use App\Models\WhatsappTemplate;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Log;

/**
 * Maps logical reminder keys (used in code) to approved WhatsappTemplate rows.
 * Twilio sync stores templates under friendly_name, which often differs from those keys.
 */
final class ReminderTemplateResolver
{
    /**
     * Normalize teacher zoom URL for templates (https prefix).
     */
    public static function normalizeZoomLink(?string $raw): string
    {
        if ($raw === null || trim($raw) === '') {
            return '';
        }
        $u = trim($raw);
        if (! str_starts_with($u, 'http://') && ! str_starts_with($u, 'https://')) {
            $u = 'https://' . ltrim($u, '/');
        }

        return $u;
    }

    /**
     * Build Twilio ContentVariables for student session reminders from the synced template body.
     * Meta/Twilio templates often use {{3}} for the zoom line while code assumed {{4}}; misaligned
     * slots make the zoom line show the session title or another field.
     */
    public static function studentSessionReminderParams(
        ?WhatsappTemplate $template,
        string $title,
        string $time,
        string $teacher,
        string $zoomUrl,
    ): array {
        $body = $template?->body_template ?? '';
        $max = self::maxNumericPlaceholder($body);
        $zoomSlot = self::detectZoomPlaceholderSlot($body);

        if ($zoomSlot === null && $max === 3 && self::bodySuggestsThirdSlotIsZoom($body)) {
            $zoomSlot = '3';
        }

        $params = match (true) {
            $max === 2 => self::studentParamsTwoSlots($body, $title, $time, $teacher, $zoomUrl, $zoomSlot),
            $max === 3 => self::studentParamsThreeSlots($body, $title, $time, $teacher, $zoomUrl, $zoomSlot),
            default => self::studentParamsFourOrMoreSlots($title, $time, $teacher, $zoomUrl, $zoomSlot),
        };

        if ($max <= 0) {
            return [
                '1' => $title,
                '2' => $time,
                '3' => $teacher,
                '4' => $zoomUrl,
            ];
        }

        $filtered = [];
        for ($i = 1; $i <= $max; $i++) {
            $k = (string) $i;
            if (array_key_exists($k, $params)) {
                $filtered[$k] = $params[$k];
            }
        }

        return $filtered;
    }

    /**
     * @return array<string, string>
     */
    private static function studentParamsTwoSlots(
        string $body,
        string $title,
        string $time,
        string $teacher,
        string $zoomUrl,
        ?string $zoomSlot,
    ): array {
        if ($zoomSlot === '2') {
            return ['1' => $title, '2' => $zoomUrl];
        }

        foreach (preg_split('/\R/u', $body) ?: [] as $line) {
            if (str_contains($line, '{{2}}')
                && (str_contains(mb_strtolower($line), 'معلم') || str_contains($line, '👨‍🏫'))) {
                return ['1' => $title, '2' => $teacher];
            }
        }

        return ['1' => $title, '2' => $time];
    }

    /**
     * @return array<string, string>
     */
    private static function studentParamsThreeSlots(
        string $body,
        string $title,
        string $time,
        string $teacher,
        string $zoomUrl,
        ?string $zoomSlot,
    ): array {
        if ($zoomSlot === '3' || ($zoomSlot === null && self::bodySuggestsThirdSlotIsZoom($body))) {
            return ['1' => $title, '2' => $time, '3' => $zoomUrl];
        }

        return ['1' => $title, '2' => $time, '3' => $teacher];
    }

    /**
     * @return array<string, string>
     */
    private static function studentParamsFourOrMoreSlots(
        string $title,
        string $time,
        string $teacher,
        string $zoomUrl,
        ?string $zoomSlot,
    ): array {
        $params = [
            '1' => $title,
            '2' => $time,
            '3' => $teacher,
            '4' => $zoomUrl,
        ];

        if ($zoomSlot !== null && isset($params[$zoomSlot]) && $zoomSlot !== '4') {
            $displaced = $params[$zoomSlot];
            $params[$zoomSlot] = $zoomUrl;
            $params['4'] = $displaced;
        }

        return $params;
    }

    private static function maxNumericPlaceholder(string $body): int
    {
        if ($body === '' || ! preg_match_all('/\{\{(\d+)\}\}/', $body, $m)) {
            return 0;
        }

        return max(array_map(intval(...), $m[1]));
    }

    private static function detectZoomPlaceholderSlot(string $body): ?string
    {
        $lines = preg_split('/\R/u', $body) ?: [];
        foreach ($lines as $line) {
            if (! self::lineLooksLikeZoomLine($line)) {
                continue;
            }
            if (preg_match_all('/\{\{(\d+)\}\}/', $line, $m) && $m[1] !== []) {
                return $m[1][array_key_last($m[1])];
            }
        }

        if (preg_match('/(?:رابط|زوم|zoom)\s*[^\n]*\{\{(\d+)\}\}/iu', $body, $m)) {
            return $m[1];
        }
        if (preg_match('/\{\{(\d+)\}\}[^\n]*(?:رابط|زوم|zoom)/iu', $body, $m)) {
            return $m[1];
        }

        return null;
    }

    private static function lineLooksLikeZoomLine(string $line): bool
    {
        $l = mb_strtolower($line);

        return str_contains($l, 'رابط')
            || str_contains($l, 'زوم')
            || str_contains($line, 'zoom')
            || str_contains($l, 'join')
            || str_contains($l, 'انضمام');
    }

    private static function bodySuggestsThirdSlotIsZoom(string $body): bool
    {
        return (bool) preg_match('/(?:رابط|زوم|zoom).*\{\{3\}\}|\{\{3\}\}.*(?:رابط|زوم|zoom)/usiu', $body);
    }

    /**
     * @param  Collection<int, WhatsappTemplate>  $approved  All approved templates (not pre-keyed).
     */
    public static function resolve(string $logicalKey, Collection $approved): ?WhatsappTemplate
    {
        $byName = $approved->keyBy('name');

        $configuredName = config("whatsapp.reminder_templates.{$logicalKey}");
        if (is_string($configuredName) && $configuredName !== '') {
            $t = $byName->get($configuredName);
            if ($t !== null) {
                return $t;
            }
        }

        $configuredSid = config("whatsapp.reminder_template_sids.{$logicalKey}");
        if (is_string($configuredSid) && $configuredSid !== '') {
            $t = $approved->firstWhere('content_sid', $configuredSid);
            if ($t !== null) {
                return $t;
            }
        }

        $fallback = $byName->get($logicalKey);
        if ($fallback === null) {
            Log::warning('Reminder template not resolved; using plain-text fallback', [
                'logical_key'     => $logicalKey,
                'configured_name' => $configuredName ?: null,
                'configured_sid'  => $configuredSid ?: null,
                'approved_names'  => $approved->pluck('name')->values()->all(),
            ]);
        }

        return $fallback;
    }

    /**
     * Human-readable body for inbox / DB when using a template (substitute {{1}}.. placeholders).
     */
    public static function resolveBody(?WhatsappTemplate $template, array $params, string $fallback): string
    {
        if ($template === null) {
            return $fallback;
        }
        $body = $template->body_template;
        foreach ($params as $key => $val) {
            $body = str_replace('{{' . $key . '}}', (string) $val, $body);
        }

        return $body;
    }
}
