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
