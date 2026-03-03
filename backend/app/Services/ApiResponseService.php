<?php

declare(strict_types=1);

namespace App\Services;

use Illuminate\Http\JsonResponse;

class ApiResponseService
{
    /**
     * Return a success JSON response.
     */
    public function success(mixed $data = null, string $message = 'OK', array $meta = [], int $code = 200): JsonResponse
    {
        $response = [
            'success' => true,
            'message' => $message,
            'data'    => $data,
        ];

        if (!empty($meta)) {
            $response['meta'] = $meta;
        }

        return response()->json($response, $code);
    }

    /**
     * Return an error JSON response.
     */
    public function error(string $message, array $errors = [], int $code = 400): JsonResponse
    {
        $response = [
            'success' => false,
            'message' => $message,
        ];

        if (!empty($errors)) {
            $response['errors'] = $errors;
        }

        return response()->json($response, $code);
    }

    /**
     * Return a paginated success response with meta info.
     */
    public function paginated(mixed $paginator, string $message = 'OK'): JsonResponse
    {
        return $this->success(
            data: $paginator->items(),
            message: $message,
            meta: [
                'current_page' => $paginator->currentPage(),
                'per_page'     => $paginator->perPage(),
                'total'        => $paginator->total(),
                'last_page'    => $paginator->lastPage(),
            ]
        );
    }
}
