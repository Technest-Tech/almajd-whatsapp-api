<?php

declare(strict_types=1);

namespace App\Services;

use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Database\Eloquent\Model;

/**
 * Base CRUD service for simple models (Students, Teachers, Guardians, Tags).
 */
abstract class BaseCrudService
{
    abstract protected function model(): string;

    /**
     * List with pagination and optional search.
     */
    public function list(array $filters = [], int $perPage = 20): LengthAwarePaginator
    {
        $query = $this->model()::query();

        if (!empty($filters['search'])) {
            $search = $filters['search'];
            $query->where(function ($q) use ($search) {
                foreach ($this->searchableColumns() as $col) {
                    $q->orWhere($col, 'like', "%{$search}%");
                }
            });
        }

        $this->applyFilters($query, $filters);

        return $query->latest()->paginate($perPage);
    }

    /**
     * Get by ID with optional relations.
     */
    public function show(int $id, array $with = []): Model
    {
        return $this->model()::with($with)->findOrFail($id);
    }

    /**
     * Create a new record.
     */
    public function create(array $data): Model
    {
        return $this->model()::create($data);
    }

    /**
     * Update an existing record.
     */
    public function update(int $id, array $data): Model
    {
        $record = $this->model()::findOrFail($id);
        $record->update($data);
        return $record->refresh();
    }

    /**
     * Delete a record (soft-delete if supported).
     */
    public function delete(int $id): void
    {
        $record = $this->model()::findOrFail($id);
        $record->delete();
    }

    /**
     * Columns to search in.
     */
    protected function searchableColumns(): array
    {
        return ['name'];
    }

    /**
     * Apply additional filters (override in child services).
     */
    protected function applyFilters($query, array $filters): void
    {
        // Override in subclass
    }
}
