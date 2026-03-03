# 5. Job Scheduler Specification

## 5.1 Scheduled Jobs Overview

| Job | Schedule | Purpose |
|-----|----------|---------|
| `GenerateSessionsJob` | Weekly (Sunday 00:00) | Generate next week's sessions from active schedules |
| `CreateReminderJobsJob` | Daily (00:30) | Create reminder_jobs for tomorrow's sessions |
| `CheckSlaBreachJob` | Every minute | Check open tickets approaching SLA breach |
| `CheckFollowUpRemindersJob` | Every 5 min | Send notifications for follow-up reminders due |
| `SendReminderJob` | Continuous (queue) | Send individual WhatsApp reminder (queued) |
| `SendWhatsAppMessageJob` | Continuous (queue) | Send individual WhatsApp message (queued) |
| `ProcessInboundMessageJob` | Continuous (queue) | Process inbound webhook payload (queued) |
| `ProcessBulkImportJob` | On-demand (queue) | Process uploaded Excel file (queued) |
| `CleanupExpiredDeviceSessionsJob` | Daily (03:00) | Remove expired device sessions |

## 5.2 Session Generation Flow

```
┌──────────────────────────────────────────────────────────┐
│  GenerateSessionsJob (runs weekly, Sunday 00:00)         │
├──────────────────────────────────────────────────────────┤
│  1. Query all schedules WHERE status = 'active'          │
│  2. For each schedule:                                    │
│     a. Determine target week (next Mon → Sun)            │
│     b. Check if schedule.day_of_week falls in target     │
│     c. For matching days, create session record:          │
│        - schedule_id, session_date, start/end_time       │
│        - teacher_id (from schedule)                       │
│        - status = 'upcoming'                              │
│     d. SKIP if (schedule_id, session_date) already exists │
│        (UNIQUE constraint = natural dedupe)               │
│     e. Check teacher conflict:                            │
│        ConflictCheckerService::check(teacher, date, time)│
│        If conflict → log warning, skip session            │
│  3. Dispatch CreateReminderJobsJob for generated sessions │
│  4. Log summary: { generated, skipped, conflicts }        │
└──────────────────────────────────────────────────────────┘
```

**Admin can also trigger manually via**: `POST /schedules/generate` with custom date range.

## 5.3 Reminder Generation Flow

```
┌───────────────────────────────────────────────────────────┐
│  CreateReminderJobsJob (runs daily at 00:30)              │
├───────────────────────────────────────────────────────────┤
│  1. Query sessions WHERE session_date = tomorrow          │
│     AND status = 'upcoming'                               │
│  2. Query all active reminder_policies                    │
│  3. For each (session, policy) pair:                      │
│     a. Calculate scheduled_at:                            │
│        session_date + start_time - trigger_minutes_before │
│     b. Determine recipients based on policy.target:       │
│        - 'parent' → guardian.whatsapp_number              │
│        - 'teacher' → teacher.whatsapp_number              │
│        - 'both' → create 2 reminder_jobs                  │
│     c. Generate idempotency_key:                          │
│        "reminder:{policy_id}:{session_id}:{recipient}"    │
│     d. INSERT reminder_job with ON CONFLICT DO NOTHING    │
│        (idempotency_key is UNIQUE → natural dedupe)       │
│  4. For each created reminder_job:                        │
│     Dispatch SendReminderJob with delay = scheduled_at    │
└───────────────────────────────────────────────────────────┘
```

## 5.4 SendReminderJob Execution

```
┌───────────────────────────────────────────────────────────┐
│  SendReminderJob (runs when scheduled_at arrives)         │
├───────────────────────────────────────────────────────────┤
│  1. Load reminder_job + linked policy + template          │
│  2. Check if session still 'upcoming' (not cancelled)     │
│     If cancelled → mark reminder_job as 'cancelled', exit │
│  3. Resolve template variables:                           │
│     {{student_name}}, {{session_time}}, {{teacher_name}}  │
│  4. Call WhatsAppService::sendTemplate(                   │
│        to: recipient_number,                              │
│        template: policy.template.name,                    │
│        params: resolved variables                         │
│     )                                                     │
│  5. On success → update reminder_job.status = 'sent'      │
│  6. On failure → increment retry_count                    │
│     If retry_count < 3 → re-queue with backoff            │
│     If retry_count >= 3 → status = 'failed', log reason   │
└───────────────────────────────────────────────────────────┘
```

## 5.5 SLA Breach Checker

```
┌───────────────────────────────────────────────────────────┐
│  CheckSlaBreachJob (runs every minute)                    │
├───────────────────────────────────────────────────────────┤
│  1. Query tickets WHERE sla_breached = false              │
│     AND status IN ('new', 'assigned', 'pending')          │
│     AND sla_policy_id IS NOT NULL                         │
│  2. For each ticket:                                      │
│     a. Calculate elapsed = now() - ticket.created_at      │
│     b. Load sla_policy                                    │
│     c. first_response check:                              │
│        If sla_first_response_at IS NULL                   │
│        AND elapsed > first_response_minutes               │
│        → Mark sla_breached = true                         │
│        → If auto_escalate → escalate ticket               │
│        → Broadcast SlaBreached event                      │
│     d. Warning check:                                     │
│        If elapsed > (first_response_min * warning_pct/100)│
│        → Push notification to owner "SLA warning"         │
│  3. Lightweight query: batch process, exit quickly        │
└───────────────────────────────────────────────────────────┘
```

## 5.6 Retry Policies

| Job Type | Max Retries | Backoff | Dead-Letter |
|----------|-------------|---------|-------------|
| `SendWhatsAppMessageJob` | 3 | Exponential: 30s, 120s, 300s | Move to `failed_jobs` + log |
| `SendReminderJob` | 3 | Exponential: 60s, 300s, 600s | Mark `failed` + alert admin |
| `ProcessInboundMessageJob` | 5 | Exponential: 10s, 30s, 60s, 120s, 300s | `failed_jobs` + alert |
| `ProcessBulkImportJob` | 1 | None | Mark import as failed |
| `CheckSlaBreachJob` | 0 | None (runs every minute) | Log error, next run retries |

## 5.7 Idempotency Keys

| Context | Key Format | Storage |
|---------|-----------|---------|
| Inbound WhatsApp | `wa:inbound:{wamid}` | Redis (60s) + DB UNIQUE |
| Send reminder | `reminder:{policy_id}:{session_id}:{phone}` | DB UNIQUE on reminder_jobs |
| Session generation | `(schedule_id, session_date)` | DB UNIQUE on sessions |
| Outbound message | `wa:outbound:{ticket_id}:{timestamp}:{hash}` | DB UNIQUE on whatsapp_messages |

## 5.8 Queue Topology

```
Queue Workers (Redis-backed):

  high    → ProcessInboundMessageJob, CheckSlaBreachJob
  default → SendWhatsAppMessageJob, SendReminderJob
  low     → GenerateSessionsJob, CreateReminderJobsJob, ProcessBulkImportJob
  dead    → Failed jobs after max retries (for manual inspection)
```

**Laravel Scheduler (app/Console/Kernel.php):**
```php
protected function schedule(Schedule $schedule): void
{
    $schedule->job(new GenerateSessionsJob)->weeklyOn(0, '00:00');
    $schedule->job(new CreateReminderJobsJob)->dailyAt('00:30');
    $schedule->job(new CheckSlaBreachJob)->everyMinute();
    $schedule->job(new CheckFollowUpRemindersJob)->everyFiveMinutes();
    $schedule->job(new CleanupExpiredDeviceSessionsJob)->dailyAt('03:00');
}
```

## 5.9 Dead-Letter Strategy

1. After max retries, job moves to `failed_jobs` table (Laravel default)
2. `failed_jobs` includes: job class, payload, exception, failed_at
3. Admin receives push notification for critical failures (WhatsApp send failures)
4. Admin dashboard shows "Failed Jobs" panel with retry button
5. Manual retry via API: `POST /admin/failed-jobs/{id}/retry`
6. Auto-cleanup: failed_jobs older than 30 days are archived to cold storage
