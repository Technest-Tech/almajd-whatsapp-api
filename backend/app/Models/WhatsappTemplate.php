<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\TemplateStatus;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Builder;

class WhatsappTemplate extends Model
{
    protected $fillable = [
        'name',
        'language',
        'category',
        'body_template',
        'header_type',
        'header_text',
        'footer_text',
        'status',
        'content_sid',
        'variables_schema',
        'rejection_reason',
        'synced_at',
    ];

    protected function casts(): array
    {
        return [
            'status'           => TemplateStatus::class,
            'variables_schema' => 'array',
            'synced_at'        => 'datetime',
        ];
    }

    // ── Scopes ──────────────────────────────────────────────────────────────

    public function scopeApproved(Builder $query): Builder
    {
        return $query->where('status', TemplateStatus::Approved);
    }

    public function scopePending(Builder $query): Builder
    {
        return $query->where('status', TemplateStatus::Pending);
    }

    // ── Accessors ────────────────────────────────────────────────────────────

    /**
     * Resolve template preview by substituting placeholders with dummy values.
     */
    public function resolvePreview(array $vars = []): string
    {
        $body = $this->body_template;
        foreach ($vars as $i => $value) {
            $body = str_replace('{{' . ($i + 1) . '}}', $value, $body);
        }
        return $body;
    }
}
