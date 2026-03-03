<?php

declare(strict_types=1);

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;

class LoginRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'email'       => ['required', 'email'],
            'password'    => ['required', 'string', 'min:6'],
            'device_id'   => ['required', 'string', 'max:255'],
            'device_name' => ['nullable', 'string', 'max:255'],
            'fcm_token'   => ['nullable', 'string', 'max:500'],
        ];
    }
}
