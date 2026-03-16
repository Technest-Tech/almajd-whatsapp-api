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
            'name'            => 'required|string|max:255',
            'whatsapp_number' => 'required|string|max:20',
            'zoom_link'       => 'nullable|url|max:255',
        ];
    }

    protected function updateRules(): array
    {
        return [
            'name'            => 'sometimes|string|max:255',
            'whatsapp_number' => 'sometimes|string|max:20',
            'zoom_link'       => 'nullable|url|max:255',
        ];
    }
}
