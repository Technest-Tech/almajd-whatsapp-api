<?php

return [

    /*
    |--------------------------------------------------------------------------
    | WhatsApp BSP Provider
    |--------------------------------------------------------------------------
    | Supported: 'twilio', '360dialog'
    */
    'provider' => env('WHATSAPP_PROVIDER', 'twilio'),

    /*
    |--------------------------------------------------------------------------
    | Twilio Credentials
    |--------------------------------------------------------------------------
    */
    'twilio' => [
        'account_sid' => env('TWILIO_ACCOUNT_SID'),
        'auth_token'  => env('TWILIO_AUTH_TOKEN'),
        'from_number' => env('TWILIO_WHATSAPP_NUMBER'), // whatsapp:+14155238886
    ],

    /*
    |--------------------------------------------------------------------------
    | 360dialog Credentials (future)
    |--------------------------------------------------------------------------
    */
    '360dialog' => [
        'api_key'  => env('DIALOG360_API_KEY'),
        'base_url' => env('DIALOG360_BASE_URL', 'https://waba.360dialog.io/v1'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Webhook Verification
    |--------------------------------------------------------------------------
    */
    'webhook_secret'  => env('WHATSAPP_WEBHOOK_SECRET'),
    'verify_token'    => env('WHATSAPP_VERIFY_TOKEN', 'almajd_verify'),

    /*
    |--------------------------------------------------------------------------
    | Session Window
    |--------------------------------------------------------------------------
    | WhatsApp allows free-form messaging within 24 hours of last inbound.
    | Outside the window, only approved templates can be sent.
    */
    'session_window_hours' => (int) env('WHATSAPP_SESSION_WINDOW_HOURS', 24),

    /*
    |--------------------------------------------------------------------------
    | Retry Configuration
    |--------------------------------------------------------------------------
    */
    'max_retries'     => (int) env('WHATSAPP_MAX_RETRIES', 3),
    'retry_backoff'   => [30, 120, 300], // seconds between retries
];
