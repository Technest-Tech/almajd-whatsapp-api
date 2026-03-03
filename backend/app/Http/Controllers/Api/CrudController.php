<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\ApiResponseService;
use App\Services\BaseCrudService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

abstract class CrudController extends Controller
{
    public function __construct(
        protected readonly BaseCrudService $service,
        protected readonly ApiResponseService $response,
    ) {}

    abstract protected function storeRules(): array;
    abstract protected function updateRules(): array;

    public function index(Request $request): JsonResponse
    {
        $paginator = $this->service->list(
            filters: $request->all(),
            perPage: (int) $request->input('per_page', 20),
        );

        return $this->response->paginated($paginator);
    }

    public function show(int $id): JsonResponse
    {
        return $this->response->success($this->service->show($id));
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate($this->storeRules());
        $record = $this->service->create($data);
        return $this->response->success($record, 'Created', code: 201);
    }

    public function update(Request $request, int $id): JsonResponse
    {
        $data = $request->validate($this->updateRules());
        $record = $this->service->update($id, $data);
        return $this->response->success($record, 'Updated');
    }

    public function destroy(int $id): JsonResponse
    {
        $this->service->delete($id);
        return $this->response->success(message: 'Deleted');
    }
}
