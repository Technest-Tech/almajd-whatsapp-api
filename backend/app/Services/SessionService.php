<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\ClassSession;

class SessionService
{
    /**
     * List sessions with filters.
     */
    public function list(array $filters = [], int $perPage = 20)
    {
        $query = ClassSession::with(['teacher', 'student', 'scheduleEntry'])
            ->orderBy('session_date')
            ->orderBy('start_time');

        if (!empty($filters['date'])) {
            $query->where('session_date', $filters['date']);
        }
        if (!empty($filters['from'])) {
            $query->where('session_date', '>=', $filters['from']);
        }
        if (!empty($filters['to'])) {
            $query->where('session_date', '<=', $filters['to']);
        }
        if (!empty($filters['status'])) {
            $query->where('status', $filters['status']);
        }
        if (!empty($filters['teacher_id'])) {
            $query->where('teacher_id', $filters['teacher_id']);
        }
        if (!empty($filters['supervisor_id'])) {
            $query->where('supervisor_id', $filters['supervisor_id']);
        }

        return $query->paginate($perPage);
    }

    /**
     * Show a single session.
     */
    public function show(int $id): ClassSession
    {
        return ClassSession::with(['teacher', 'scheduleEntry.schedule'])->findOrFail($id);
    }

    /**
     * Update session status (complete or cancel).
     */
    public function updateStatus(int $id, string $status, ?string $reason = null): ClassSession
    {
        $session = ClassSession::findOrFail($id);

        $data = ['status' => $status];

        if ($status === 'cancelled' && $reason) {
            $data['cancellation_reason'] = $reason;
        }

        $session->update($data);

        return $session->refresh();
    }
}
