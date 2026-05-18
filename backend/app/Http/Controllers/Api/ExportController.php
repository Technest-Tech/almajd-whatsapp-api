<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Support\Facades\DB;
use Shuchkin\SimpleXLSXGen;

class ExportController extends Controller
{
    public function exportTeachersConnectrs()
    {
        $query = "
            SELECT
              ct.id as teacher_id,
              ct.name as teacher_name,
              ctt.student_name,
              COALESCE(CAST(ctt.student_id AS CHAR), 'غير مرتبط') as student_id,
              GROUP_CONCAT(DISTINCT ctt.day ORDER BY FIELD(ctt.day,'Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday') SEPARATOR ' | ') as days,
              MIN(ctt.start_time) as start_time,
              MAX(ctt.finish_time) as end_time
            FROM calendar_teacher_timetables ctt
            JOIN calendar_teachers ct ON ct.id = ctt.teacher_id
            WHERE ctt.status = 'active'
            GROUP BY ct.id, ct.name, ctt.student_name, ctt.student_id
            ORDER BY ct.name, ctt.student_name
        ";

        $results = DB::select($query);

        $data = [];
        $data[] = [
            "<center><b>#</b></center>",
            "<center><b>Teacher ID</b></center>",
            "<center><b>اسم المعلم</b></center>",
            "<center><b>اسم الطالب</b></center>",
            "<center><b>Student ID</b></center>",
            "<center><b>أيام الحصص</b></center>",
            "<center><b>أول موعد</b></center>",
            "<center><b>آخر موعد</b></center>",
            "<center><b>حالة الربط</b></center>",
        ];

        $rowNum = 1;
        foreach ($results as $row) {
            $isLinked = $row->student_id !== 'غير مرتبط' && trim($row->student_id) !== '';
            $linkLabel = $isLinked ? '✅ مرتبط' : '⚠️ غير مرتبط';

            $data[] = [
                $rowNum++,
                $row->teacher_id,
                $row->teacher_name,
                $row->student_name,
                $row->student_id,
                $row->days,
                $row->start_time,
                $row->end_time,
                $linkLabel,
            ];
        }

        $xlsx = SimpleXLSXGen::fromArray($data);
        $xlsx->downloadAs('teachers_connectrs.xlsx');
        exit;
    }
}
