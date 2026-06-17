<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\ClassSession;

class SessionService
{
    /**
     * List sessions with filters.
     *
     * @param int|null $shiftWindowUserId When set, scope to every session whose
     *        weekday + start time falls inside one of this user's active shifts
     *        (the "my shift" view). This replaces single-owner supervisor_id
     *        filtering so all supervisors sharing a shift window see the same
     *        sessions, per the shift-based visibility model.
     */
    public function list(array $filters = [], int $perPage = 20, ?int $shiftWindowUserId = null)
    {
        $query = ClassSession::with([
            'teacher',
            'student',
            'scheduleEntry',
            'supervisor' => static function ($q): void {
                $q->select('id', 'name');
            },
        ])
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

        if ($shiftWindowUserId !== null) {
            $this->scopeToShiftWindow($query, $shiftWindowUserId);
        }

        return $query->paginate($perPage);
    }

    /**
     * Constrain the query to sessions covered by the user's active shifts.
     *
     * A session matches when an active shift exists for the user on the session's
     * weekday (shifts.day_of_week uses Carbon's 0=Sun..6=Sat, equal to MySQL
     * DAYOFWEEK()-1) and the session start time falls inside the shift window —
     * including overnight shifts where end_time wraps past midnight.
     */
    private function scopeToShiftWindow($query, int $userId): void
    {
        $query->whereExists(function ($sub) use ($userId): void {
            $sub->selectRaw('1')
                ->from('shifts')
                ->where('shifts.user_id', $userId)
                ->where('shifts.is_active', true)
                ->whereRaw('shifts.day_of_week = (DAYOFWEEK(class_sessions.session_date) - 1)')
                ->where(function ($w): void {
                    // Normal same-day shift (e.g. 17:00–21:30).
                    $w->where(function ($n): void {
                        $n->whereColumn('shifts.end_time', '>', 'shifts.start_time')
                          ->whereColumn('class_sessions.start_time', '>=', 'shifts.start_time')
                          ->whereColumn('class_sessions.start_time', '<', 'shifts.end_time');
                    })
                    // Overnight shift wrapping midnight (e.g. 22:00–00:30).
                    ->orWhere(function ($o): void {
                        $o->whereColumn('shifts.end_time', '<=', 'shifts.start_time')
                          ->where(function ($x): void {
                              $x->whereColumn('class_sessions.start_time', '>=', 'shifts.start_time')
                                ->orWhereColumn('class_sessions.start_time', '<', 'shifts.end_time');
                          });
                    });
                });
        });
    }

    /**
     * Show a single session.
     */
    public function show(int $id): ClassSession
    {
        return ClassSession::with([
            'teacher',
            'student',
            'scheduleEntry.schedule',
            'supervisor' => static function ($q): void {
                $q->select('id', 'name');
            },
        ])->findOrFail($id);
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
