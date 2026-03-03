<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Services\ApiResponseService;
use App\Services\GuardianService;

class GuardianController extends CrudController
{
    public function __construct(GuardianService $service, ApiResponseService $response)
    {
        parent::__construct($service, $response);
    }

    protected function storeRules(): array
    {
        return [
            'name'  => 'required|string|max:255',
            'phone' => 'required|string|max:20|unique:guardians,phone',
            'email' => 'nullable|email|max:255',
            'notes' => 'nullable|string|max:2000',
        ];
    }

    protected function updateRules(): array
    {
        return [
            'name'  => 'sometimes|string|max:255',
            'phone' => 'sometimes|string|max:20',
            'email' => 'nullable|email|max:255',
            'notes' => 'nullable|string|max:2000',
        ];
    }
}
