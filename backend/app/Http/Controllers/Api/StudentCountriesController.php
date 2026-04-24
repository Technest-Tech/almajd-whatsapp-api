<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CalendarTeacherTimetable;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class StudentCountriesController extends Controller
{
    private const VALID_COUNTRIES = ['canada', 'uk', 'eg'];
    private const DAYS_OF_WEEK = [
        'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
    ];

    public function plus(Request $request, string $country): JsonResponse
    {
        return $this->shiftHours($country, 1);
    }

    public function minus(Request $request, string $country): JsonResponse
    {
        return $this->shiftHours($country, -1);
    }

    private function shiftHours(string $country, int $hours): JsonResponse
    {
        try {
            $country = strtolower($country);

            if (!in_array($country, self::VALID_COUNTRIES, true)) {
                return response()->json([
                    'error' => 'Invalid country. Must be one of: ' . implode(', ', self::VALID_COUNTRIES),
                ], 400);
            }

            $timetables = CalendarTeacherTimetable::where('country', $country)
                ->where('status', 'active')
                ->get();

            if ($timetables->isEmpty()) {
                return response()->json([
                    'message' => 'No active timetables found for ' . $country,
                    'updated_count' => 0,
                ]);
            }

            $updatedCount = 0;
            foreach ($timetables as $timetable) {
                $startTime = Carbon::createFromFormat('H:i:s', $timetable->start_time);
                $finishTime = Carbon::createFromFormat('H:i:s', $timetable->finish_time);

                $newStartTime = $startTime->copy()->addHours($hours);
                $newFinishTime = $finishTime->copy()->addHours($hours);

                $day = $timetable->day;
                if ($hours > 0 && $newStartTime->format('H:i:s') < $startTime->format('H:i:s')) {
                    $day = $this->shiftDay($day, 1);
                } elseif ($hours < 0 && $newStartTime->format('H:i:s') > $startTime->format('H:i:s')) {
                    $day = $this->shiftDay($day, -1);
                }

                $timetable->update([
                    'start_time' => $newStartTime->format('H:i:s'),
                    'finish_time' => $newFinishTime->format('H:i:s'),
                    'day' => $day,
                ]);

                $updatedCount++;
            }

            $verb = $hours > 0 ? 'added to' : 'subtracted from';
            return response()->json([
                'message' => abs($hours) . " Hour successfully {$verb} {$country}",
                'updated_count' => $updatedCount,
                'country' => $country,
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'error' => 'Failed to update timetables: ' . $e->getMessage(),
            ], 500);
        }
    }

    private function shiftDay(string $day, int $offset): string
    {
        $index = array_search($day, self::DAYS_OF_WEEK, true);
        if ($index === false) {
            return $day;
        }
        $newIndex = ($index + $offset + 7) % 7;
        return self::DAYS_OF_WEEK[$newIndex];
    }
}
