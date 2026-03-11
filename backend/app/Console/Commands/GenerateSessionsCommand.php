<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Models\ClassSession;
use App\Models\ScheduleEntry;
use App\Models\Student;
use Carbon\Carbon;
use Illuminate\Console\Command;

class GenerateSessionsCommand extends Command
{
    protected $signature = 'sessions:generate
                            {--student= : Only generate for a specific student ID}
                            {--months=3  : How many months ahead to generate (default: 3)}
                            {--force     : Force regeneration even if future sessions already exist}';

    protected $description = 'Auto-generate class sessions for all active students up to N months in advance. 
                              Skips generation if the student already has sessions covering the window.';

    public function handle(): int
    {
        $months    = (int) $this->option('months');
        $force     = $this->option('force');
        $studentId = $this->option('student');

        $query = Student::whereNotNull('id'); // all students; filter inactive via schedule entries (is_active flag)
        if ($studentId) {
            $query->where('id', $studentId);
        }

        $students = $query->get();
        $totalCreated = 0;

        foreach ($students as $student) {
            $created = $this->generateForStudent($student, $months, $force);
            $totalCreated += $created;
            if ($created > 0) {
                $this->line("  [Student #{$student->id} {$student->name}] Created {$created} sessions");
            }
        }

        $this->info("✅ Done. Total sessions created: {$totalCreated}");
        return Command::SUCCESS;
    }

    /**
     * Generate sessions for one student.
     * Smart logic: only generates if the student's future scheduled sessions
     * cover less than THRESHOLD_WEEKS weeks from today.
     */
    public function generateForStudent(Student $student, int $months = 3, bool $force = false): int
    {
        $entries = $student->scheduleEntries()->where('is_active', true)->get();
        if ($entries->isEmpty()) {
            return 0;
        }

        $today      = Carbon::today();
        $windowEnd  = $today->copy()->addMonths($months)->endOfMonth();

        if (!$force) {
            // Check how far ahead existing future sessions reach
            $lastFutureSession = ClassSession::where('student_id', $student->id)
                ->where('session_date', '>=', $today->toDateString())
                ->whereIn('status', ['scheduled', 'rescheduled'])
                ->orderByDesc('session_date')
                ->value('session_date');

            if ($lastFutureSession) {
                $lastDate = Carbon::parse($lastFutureSession);
                // If covered until > 4 weeks away, skip
                if ($lastDate->diffInWeeks($today) >= 4) {
                    return 0;
                }
            }
        }

        $created = 0;

        foreach ($entries as $entry) {
            // Start from today (or start of current month — whichever is earlier)
            $current = $today->copy()->startOfMonth();

            // Fast-forward to the first occurrence of the required day of week
            while ($current->dayOfWeek !== $entry->day_of_week) {
                $current->addDay();
            }

            while ($current->lte($windowEnd)) {
                // Skip dates in the past
                if ($current->lt($today)) {
                    $this->advance($current, $entry->recurrence);
                    continue;
                }

                // Skip if session already exists for this entry + date
                $exists = ClassSession::where('student_id', $student->id)
                    ->where('schedule_entry_id', $entry->id)
                    ->where('session_date', $current->toDateString())
                    ->exists();

                if (!$exists) {
                    ClassSession::create([
                        'schedule_entry_id' => $entry->id,
                        'student_id'        => $student->id,
                        'teacher_id'        => $entry->teacher_id,
                        'title'             => $entry->title,
                        'session_date'      => $current->toDateString(),
                        'start_time'        => $entry->start_time,
                        'end_time'          => $entry->end_time,
                        'status'            => 'scheduled',
                    ]);
                    $created++;
                }

                $this->advance($current, $entry->recurrence);
            }
        }

        return $created;
    }

    private function advance(Carbon $date, string $recurrence): void
    {
        match ($recurrence) {
            'biweekly' => $date->addWeeks(2),
            'once'     => $date->addYears(100), // effectively stop
            default    => $date->addWeek(),       // weekly
        };
    }
}
