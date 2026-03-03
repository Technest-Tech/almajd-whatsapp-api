<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\Reminder;

class ReminderService
{
    /**
     * List reminders with filters.
     */
    public function list(array $filters = [], int $perPage = 20)
    {
        $query = Reminder::with('classSession')
            ->orderBy('scheduled_at', 'desc');

        if (!empty($filters['status'])) {
            $query->where('status', $filters['status']);
        }
        if (!empty($filters['type'])) {
            $query->where('type', $filters['type']);
        }
        if (!empty($filters['from'])) {
            $query->where('scheduled_at', '>=', $filters['from']);
        }
        if (!empty($filters['to'])) {
            $query->where('scheduled_at', '<=', $filters['to']);
        }

        return $query->paginate($perPage);
    }

    /**
     * Create a new reminder (manual or session-linked).
     */
    public function create(array $data): Reminder
    {
        return Reminder::create($data);
    }

    /**
     * Cancel a pending reminder.
     */
    public function cancel(int $id): Reminder
    {
        $reminder = Reminder::where('status', 'pending')->findOrFail($id);
        $reminder->update(['status' => 'cancelled']);
        return $reminder->refresh();
    }

    /**
     * Bulk-create reminders for a session (all guardians of enrolled students).
     */
    public function createSessionReminders(int $sessionId, string $templateName, \Carbon\Carbon $scheduledAt, array $recipients): int
    {
        $count = 0;

        foreach ($recipients as $recipient) {
            Reminder::create([
                'type'              => 'session_reminder',
                'class_session_id'  => $sessionId,
                'recipient_phone'   => $recipient['phone'],
                'recipient_name'    => $recipient['name'] ?? null,
                'template_name'     => $templateName,
                'scheduled_at'      => $scheduledAt,
                'status'            => 'pending',
            ]);
            $count++;
        }

        return $count;
    }
}
