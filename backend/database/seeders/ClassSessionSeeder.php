<?php

namespace Database\Seeders;

use App\Models\ClassSession;
use App\Models\Student;
use App\Models\Teacher;
use Illuminate\Database\Seeder;
use Carbon\Carbon;

class ClassSessionSeeder extends Seeder
{
    public function run(): void
    {
        // ── Create Teachers ──
        $teachers = collect([
            ['name' => 'أ. محمد علي',    'phone' => '+966501001001'],
            ['name' => 'أ. فاطمة أحمد',  'phone' => '+966501001002'],
            ['name' => 'أ. عبدالله سعد',  'phone' => '+966501001003'],
            ['name' => 'أ. نورة خالد',    'phone' => '+966501001004'],
        ])->map(function ($data) {
            return Teacher::firstOrCreate(
                ['phone' => $data['phone']],
                $data
            );
        });

        $students = Student::all();
        if ($students->isEmpty()) {
            $this->command->warn('No students found. Please create students first.');
            return;
        }

        $today = Carbon::today();

        // ── Class sessions for today ──
        $sessions = [
            // Passed sessions (earlier today)
            [
                'title'      => 'حفظ سورة البقرة',
                'start_time' => '08:00',
                'end_time'   => '09:00',
                'status'     => 'completed',
                'teacher'    => 0,
                'student'    => 0,
            ],
            [
                'title'      => 'مراجعة جزء عم',
                'start_time' => '09:00',
                'end_time'   => '10:00',
                'status'     => 'completed',
                'teacher'    => 0,
                'student'    => 1,
            ],
            [
                'title'      => 'قواعد النحو',
                'start_time' => '10:00',
                'end_time'   => '11:00',
                'status'     => 'completed',
                'teacher'    => 1,
                'student'    => 0,
            ],
            [
                'title'      => 'درس ملغى - الرياضيات',
                'start_time' => '11:00',
                'end_time'   => '12:00',
                'status'     => 'cancelled',
                'teacher'    => 2,
                'student'    => 1,
                'cancellation_reason' => 'غياب الطالب',
            ],

            // Current session (happening NOW)
            [
                'title'      => 'تجويد القرآن',
                'start_time' => Carbon::now()->subMinutes(20)->format('H:i'),
                'end_time'   => Carbon::now()->addMinutes(40)->format('H:i'),
                'status'     => 'scheduled',
                'teacher'    => 0,
                'student'    => 0,
            ],
            [
                'title'      => 'محادثة إنجليزية',
                'start_time' => Carbon::now()->subMinutes(10)->format('H:i'),
                'end_time'   => Carbon::now()->addMinutes(50)->format('H:i'),
                'status'     => 'scheduled',
                'teacher'    => 3,
                'student'    => 1,
            ],

            // Upcoming sessions (later today)
            [
                'title'      => 'حل تمارين الرياضيات',
                'start_time' => Carbon::now()->addHours(1)->format('H:i'),
                'end_time'   => Carbon::now()->addHours(2)->format('H:i'),
                'status'     => 'scheduled',
                'teacher'    => 2,
                'student'    => 0,
            ],
            [
                'title'      => 'إملاء وخط',
                'start_time' => Carbon::now()->addHours(2)->format('H:i'),
                'end_time'   => Carbon::now()->addHours(3)->format('H:i'),
                'status'     => 'scheduled',
                'teacher'    => 1,
                'student'    => 1,
            ],
            [
                'title'      => 'مراجعة شاملة',
                'start_time' => Carbon::now()->addHours(3)->format('H:i'),
                'end_time'   => Carbon::now()->addHours(4)->format('H:i'),
                'status'     => 'scheduled',
                'teacher'    => 0,
                'student'    => 0,
            ],
            // Rescheduled session
            [
                'title'      => 'قواعد إنجليزية',
                'start_time' => '14:00',
                'end_time'   => '15:00',
                'status'     => 'rescheduled',
                'teacher'    => 3,
                'student'    => 0,
                'rescheduled_date'       => $today->copy()->addDays(2)->toDateString(),
                'rescheduled_start_time' => '16:00',
                'rescheduled_end_time'   => '17:00',
            ],
        ];

        foreach ($sessions as $s) {
            $teacherIdx = min($s['teacher'], $teachers->count() - 1);
            $studentIdx = min($s['student'], $students->count() - 1);

            ClassSession::create([
                'student_id'             => $students[$studentIdx]->id,
                'teacher_id'             => $teachers[$teacherIdx]->id,
                'title'                  => $s['title'],
                'session_date'           => $today,
                'start_time'             => $s['start_time'],
                'end_time'               => $s['end_time'],
                'status'                 => $s['status'],
                'cancellation_reason'    => $s['cancellation_reason'] ?? null,
                'rescheduled_date'       => $s['rescheduled_date'] ?? null,
                'rescheduled_start_time' => $s['rescheduled_start_time'] ?? null,
                'rescheduled_end_time'   => $s['rescheduled_end_time'] ?? null,
            ]);
        }

        $this->command->info('✅ Created ' . count($sessions) . ' class sessions for today + 4 teachers.');
    }
}
