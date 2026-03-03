<?php

declare(strict_types=1);

namespace App\Http\Requests\Auth;

use App\Enums\UserAvailability;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateAvailabilityRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'availability' => ['required', Rule::enum(UserAvailability::class)],
        ];
    }
}
