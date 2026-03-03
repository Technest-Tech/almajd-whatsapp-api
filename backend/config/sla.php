<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Default SLA Policy
    |--------------------------------------------------------------------------
    | Applied when no tag-specific SLA is matched.
    */
    'default_first_response_minutes' => (int) env('SLA_FIRST_RESPONSE_MIN', 5),
    'default_resolution_minutes'     => (int) env('SLA_RESOLUTION_MIN', 60),

    /*
    |--------------------------------------------------------------------------
    | Warning Threshold
    |--------------------------------------------------------------------------
    | Percentage of SLA time elapsed before sending a warning notification.
    */
    'warning_threshold_pct' => (int) env('SLA_WARNING_PCT', 80),

    /*
    |--------------------------------------------------------------------------
    | Auto-Escalation
    |--------------------------------------------------------------------------
    | If true, breached tickets are automatically escalated to admin.
    */
    'auto_escalate' => (bool) env('SLA_AUTO_ESCALATE', false),

    /*
    |--------------------------------------------------------------------------
    | Check Interval
    |--------------------------------------------------------------------------
    | How often the SLA breach checker job runs (in seconds).
    */
    'check_interval_seconds' => (int) env('SLA_CHECK_INTERVAL', 60),
];
