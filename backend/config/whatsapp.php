<?php

return [

    /*
    |--------------------------------------------------------------------------
    | WhatsApp BSP Provider
    |--------------------------------------------------------------------------
    | Supported: 'twilio', 'wasender', '360dialog'
    |
    | Switch by setting WHATSAPP_PROVIDER in .env.
    | 'wasender' = QR-linked personal session (no per-message fees, no template approval)
    | 'twilio'   = Meta BSP (official, green tick, per-message pricing)
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
        'from_number' => env('TWILIO_WHATSAPP_NUMBER'), // e.g. +201217770240 (production sender)
    ],

    /*
    |--------------------------------------------------------------------------
    | WasenderAPI Credentials
    |--------------------------------------------------------------------------
    | API key is generated per-session in the Wasender dashboard after
    | connecting your WhatsApp account via QR code.
    |
    | Webhook secret is set in Session settings on the Wasender dashboard.
    | Leave WASENDER_WEBHOOK_SECRET empty to skip signature verification (dev only).
    */
    'wasender' => [
        'api_key'        => env('WASENDER_API_KEY'),
        'base_url'       => env('WASENDER_BASE_URL', 'https://www.wasenderapi.com/api'),
        'from_number'    => env('WASENDER_FROM_NUMBER'), // Your linked WA number e.g. +201234567890
        'webhook_secret' => env('WASENDER_WEBHOOK_SECRET'),
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
    | Teacher WhatsApp confirmation (reply 1/2 to session reminders)
    |--------------------------------------------------------------------------
    | Ignore awaiting reminders older than this when matching inbound replies,
    | so a stale reminder cannot change class status from unrelated messages.
    */
    'teacher_confirmation_max_age_hours' => (int) env('WHATSAPP_TEACHER_CONFIRMATION_MAX_AGE_HOURS', 72),

    /*
    |--------------------------------------------------------------------------
    | Session reminder templates (Twilio Content / Meta approved)
    |--------------------------------------------------------------------------
    | Auto-scheduled reminders look up WhatsappTemplate by logical key (e.g. student_before_reminder).
    | If your DB row uses Twilio friendly_name from sync, set the matching env to that name, or set
    | *_SID to the Content SID (HX...). Empty env = use logical key as DB name.
    */
    'reminder_templates' => [
        'student_before_reminder'   => env('WHATSAPP_REMINDER_STUDENT_BEFORE'),
        'teacher_before_alert'      => env('WHATSAPP_REMINDER_TEACHER_BEFORE'),
        'student_at_start_reminder' => env('WHATSAPP_REMINDER_STUDENT_AT_START'),
        'teacher_at_start_request'  => env('WHATSAPP_REMINDER_TEACHER_AT_START'),
        'student_after_5m_alert'    => env('WHATSAPP_REMINDER_STUDENT_AFTER_5M'),
        'teacher_after_5m_request'  => env('WHATSAPP_REMINDER_TEACHER_AFTER_5M'),
        'teacher_post_end_request'  => env('WHATSAPP_REMINDER_TEACHER_POST_END'),
    ],

    'reminder_template_sids' => [
        'student_before_reminder'   => env('WHATSAPP_REMINDER_STUDENT_BEFORE_SID'),
        'teacher_before_alert'      => env('WHATSAPP_REMINDER_TEACHER_BEFORE_SID'),
        'student_at_start_reminder' => env('WHATSAPP_REMINDER_STUDENT_AT_START_SID'),
        'teacher_at_start_request'  => env('WHATSAPP_REMINDER_TEACHER_AT_START_SID'),
        'student_after_5m_alert'    => env('WHATSAPP_REMINDER_STUDENT_AFTER_5M_SID'),
        'teacher_after_5m_request'  => env('WHATSAPP_REMINDER_TEACHER_AFTER_5M_SID'),
        'teacher_post_end_request'  => env('WHATSAPP_REMINDER_TEACHER_POST_END_SID'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Retry Configuration
    |--------------------------------------------------------------------------
    */
    'max_retries'     => (int) env('WHATSAPP_MAX_RETRIES', 3),
    'retry_backoff'   => [30, 120, 300], // seconds between retries
];
