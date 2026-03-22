<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Services\ApiResponseService;
use App\Services\TeacherService;
use App\Models\Guardian;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

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

    /**
     * Sync guardian name when teacher is updated.
     *
     * Inbox uses `tickets.guardian.name` to display the contact name, so when the
     * admin changes a teacher name we also update guardians for matching
     * whatsapp numbers.
     */
    public function update(Request $request, int $id): \Illuminate\Http\JsonResponse
    {
        $teacher = $this->service->show($id);
        $oldPhone = $teacher->whatsapp_number;

        $data = $request->validate($this->updateRules());
        $updated = $this->service->update($id, $data);

        $newPhone = $updated->whatsapp_number;
        $newName = $updated->name;

        if (!empty($oldPhone) || !empty($newPhone)) {
            // Update guardians for any matching phone.
            // Only override placeholders to avoid overwriting custom guardian names.
            $phones = array_values(array_filter([$oldPhone, $newPhone], fn ($p) => $p !== null && $p !== ''));

            if (!empty($phones)) {
                Guardian::whereIn('phone', $phones)
                    ->where(function ($q) use ($oldPhone, $newPhone) {
                        $q->where('name', 'Unknown Contact')
                            ->orWhere('name', $oldPhone)
                            ->orWhere('name', $newPhone);
                    })
                    ->update(['name' => $newName]);
            }
        }

        return $this->response->success($updated, 'Updated');
    }
}
