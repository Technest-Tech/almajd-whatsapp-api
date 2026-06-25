<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Cache;

/**
 * Simple key/value application settings.
 *
 * Reads are cached (short TTL) so hot paths and long-running queue workers
 * pick up changes quickly without hammering the DB. Writes invalidate the
 * cache immediately so a switch takes effect on the next request/job.
 */
class Setting extends Model
{
    protected $fillable = ['key', 'value'];

    private const CACHE_TTL = 60; // seconds

    private static function cacheKey(string $key): string
    {
        return "setting:{$key}";
    }

    public static function get(string $key, ?string $default = null): ?string
    {
        // Cache failures (e.g. a stale root-owned file cache entry the worker
        // cannot rewrite) must NEVER break callers — fall back to a direct read.
        try {
            $value = Cache::remember(
                self::cacheKey($key),
                self::CACHE_TTL,
                fn () => self::query()->where('key', $key)->value('value')
            );
        } catch (\Throwable $e) {
            $value = self::query()->where('key', $key)->value('value');
        }

        return $value ?? $default;
    }

    public static function set(string $key, ?string $value): void
    {
        self::query()->updateOrCreate(['key' => $key], ['value' => $value]);
        try {
            Cache::forget(self::cacheKey($key));
        } catch (\Throwable $e) {
            // ignore — DB is the source of truth; cache will expire on its own
        }
    }
}
