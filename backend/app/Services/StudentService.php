<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\Student;

class StudentService extends BaseCrudService
{
    protected function model(): string
    {
        return Student::class;
    }

    protected function searchableColumns(): array
    {
        return ['name', 'phone', 'student_code'];
    }

    protected function applyFilters($query, array $filters): void
    {
        if (!empty($filters['guardian_id'])) {
            $query->where('guardian_id', $filters['guardian_id']);
        }
    }
}
