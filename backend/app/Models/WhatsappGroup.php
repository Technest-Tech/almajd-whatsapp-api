<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * A shared WhatsApp group that contains a teacher and a student together.
 *
 * Reminders for any session between that teacher and student are posted to
 * this group (group_jid) rather than the two private numbers. See the
 * whatsapp_groups migration for the full rationale.
 */
class WhatsappGroup extends Model
{
    protected $fillable = [
        'teacher_id', 'student_id', 'group_jid', 'group_name', 'whatsapp_number', 'is_active',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
        ];
    }

    public function teacher(): BelongsTo
    {
        return $this->belongsTo(Teacher::class);
    }

    public function student(): BelongsTo
    {
        return $this->belongsTo(Student::class);
    }

    /**
     * Resolve the group JID for a teacher↔student pair that is usable RIGHT NOW,
     * i.e. owned by the currently-active Wasender number. Returns null when the
     * pair has no group for the active number (callers then fall back to the
     * private number). This makes switching the active number safe: each number
     * only ever sends to groups it is actually a member of.
     */
    public static function jidFor(?int $teacherId, ?int $studentId): ?string
    {
        if (!$teacherId || !$studentId) {
            return null;
        }

        // Stored whatsapp_number and the lookup both come from the same
        // WasenderSession::fromNumber() config value, so a plain equality match
        // is exact and DB-agnostic.
        $activeNumber = \App\Services\WhatsApp\WasenderSession::fromNumber();

        return static::query()
            ->where('teacher_id', $teacherId)
            ->where('student_id', $studentId)
            ->where('is_active', true)
            ->where('whatsapp_number', $activeNumber)
            ->value('group_jid');
    }
}
