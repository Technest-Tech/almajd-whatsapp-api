<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\Schedule;
use App\Models\ScheduleEntry;

class ScheduleService
{
    /**
     * List schedules with entries count.
     */
    public function list(array $filters = [], int $perPage = 20)
    {
        $query = Schedule::withCount('entries')->latest();

        if (isset($filters['is_active'])) {
            $query->where('is_active', filter_var($filters['is_active'], FILTER_VALIDATE_BOOLEAN));
        }

        if (!empty($filters['search'])) {
            $query->where('name', 'ilike', "%{$filters['search']}%");
        }

        return $query->paginate($perPage);
    }

    /**
     * Get schedule with all entries and teacher details.
     */
    public function show(int $id): Schedule
    {
        return Schedule::with(['entries' => fn ($q) => $q->with('teacher')->orderBy('day_of_week')->orderBy('start_time')])
            ->findOrFail($id);
    }

    /**
     * Create a schedule.
     */
    public function create(array $data): Schedule
    {
        return Schedule::create($data);
    }

    /**
     * Update a schedule.
     */
    public function update(int $id, array $data): Schedule
    {
        $schedule = Schedule::findOrFail($id);
        $schedule->update($data);
        return $schedule->refresh();
    }

    /**
     * Delete a schedule and its entries.
     */
    public function delete(int $id): void
    {
        Schedule::findOrFail($id)->delete();
    }

    // ── Schedule Entries ────────────────────────────────

    /**
     * Add an entry to a schedule.
     */
    public function addEntry(int $scheduleId, array $data): ScheduleEntry
    {
        $data['schedule_id'] = $scheduleId;
        return ScheduleEntry::create($data);
    }

    /**
     * Update a schedule entry.
     */
    public function updateEntry(int $entryId, array $data): ScheduleEntry
    {
        $entry = ScheduleEntry::findOrFail($entryId);
        $entry->update($data);
        return $entry->refresh()->load('teacher');
    }

    /**
     * Delete a schedule entry.
     */
    public function deleteEntry(int $entryId): void
    {
        ScheduleEntry::findOrFail($entryId)->delete();
    }
}
