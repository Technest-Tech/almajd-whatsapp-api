<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Services\ApiResponseService;
use App\Services\TeacherService;

class TeacherController extends CrudController
{
    public function __construct(TeacherService $service, ApiResponseService $response)
    {
        parent::__construct($service, $response);
    }

    protected function storeRules(): array
    {
        return [
            'name'  => 'required|string|max:255',
            'phone' => 'nullable|string|max:20',
            'email' => 'nullable|email|max:255',
            'notes' => 'nullable|string|max:2000',
        ];
    }

    protected function updateRules(): array
    {
        return [
            'name'  => 'sometimes|string|max:255',
            'phone' => 'nullable|string|max:20',
            'email' => 'nullable|email|max:255',
            'notes' => 'nullable|string|max:2000',
        ];
    }
}
