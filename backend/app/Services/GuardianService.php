<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\Guardian;

class GuardianService extends BaseCrudService
{
    protected function model(): string
    {
        return Guardian::class;
    }

    protected function searchableColumns(): array
    {
        return ['name', 'phone', 'email'];
    }
}
