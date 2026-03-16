<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\Teacher;

class TeacherService extends BaseCrudService
{
    protected function model(): string
    {
        return Teacher::class;
    }

    protected function searchableColumns(): array
    {
        return ['name', 'whatsapp_number'];
    }
}
