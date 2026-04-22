<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\User;
use Carbon\Carbon;
use Illuminate\Database\Eloquent\Collection as EloquentCollection;

class ShiftService
{
    // Minutes a supervisor can still receive routed tickets after their shift ends
    public const GRACE_MINUTES = 15;

    /**
     * All supervisors/senior_supervisors whose shift window covers the given timestamp.
     */
    public function supervisorsOnShiftAt(Carbon $time, bool $withGrace = false): EloquentCollection
    {
        $dayOfWeek = $time->dayOfWeek; // 0=Sun … 6=Sat (Carbon, matches Shift.day_of_week)
        $timeStr   = $time->format('H:i:s');

        return User::whereHas('roles', fn ($q) =>
                $q->whereIn('name', ['supervisor', 'senior_supervisor'])
                  ->where('guard_name', 'api')
            )
            ->whereHas('shifts', function ($q) use ($dayOfWeek, $timeStr, $withGrace) {
                $q->where('day_of_week', $dayOfWeek)
                  ->where('is_active', true)
                  ->where('start_time', '<=', $timeStr);

                if ($withGrace) {
                    // Include supervisors whose shift ended within the last GRACE_MINUTES
                    $graceStr = Carbon::parse($timeStr)
                        ->subMinutes(self::GRACE_MINUTES)
                        ->format('H:i:s');
                    $q->where('end_time', '>', $graceStr);
                } else {
                    $q->where('end_time', '>', $timeStr);
                }
            })
            ->get(['id', 'name', 'max_open_tickets']);
    }

    /**
     * Supervisors on shift right now (optionally with grace window).
     */
    public function supervisorsOnShiftNow(bool $withGrace = false): EloquentCollection
    {
        return $this->supervisorsOnShiftAt(now(), $withGrace);
    }

    /**
     * Whether a specific user is currently on shift (optionally with grace).
     */
    public function isUserOnShiftNow(User $user, bool $withGrace = false): bool
    {
        $now       = now();
        $dayOfWeek = $now->dayOfWeek;
        $timeStr   = $now->format('H:i:s');

        $q = $user->shifts()
            ->where('day_of_week', $dayOfWeek)
            ->where('is_active', true)
            ->where('start_time', '<=', $timeStr);

        if ($withGrace) {
            $graceStr = $now->copy()->subMinutes(self::GRACE_MINUTES)->format('H:i:s');
            $q->where('end_time', '>', $graceStr);
        } else {
            $q->where('end_time', '>', $timeStr);
        }

        return $q->exists();
    }

}
