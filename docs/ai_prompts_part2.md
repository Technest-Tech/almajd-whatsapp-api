# AI Prompts — Part 2 (Weeks 7–12)
# Academy WhatsApp Communication & Operations System

====================================================================
# WEEK 7 — TEACHERS + BULK IMPORT
====================================================================

## BACKEND PROMPT — Week 7

```
[PASTE UNIVERSAL CONTEXT BLOCK FROM ai_implementation_guide.md]
[Paste current progress.md]

TODAY'S TASK: Week 7 Backend — Teachers module + Bulk student import

1. TEACHERS MIGRATION
teachers table:
- id, full_name (varchar 255), whatsapp_number (varchar 20 nullable),
  status (enum: active/inactive, default: active),
  timestamps, softDeletes

2. TEACHER MODEL & SERVICE
Model: Teacher. Status cast to TeacherStatus enum.
Create app/Services/Teacher/TeacherService.php:
- list(array $filters): filter by status, search by name
- create(array $data): validate whatsapp_number format if provided
- update(Teacher $teacher, array $data)
- toggleStatus(Teacher $teacher): active ↔ inactive, log audit
- delete(Teacher $teacher): softDelete — check no active schedules before deleting
  If has active schedules: throw ConflictException("Teacher has active schedules")

3. TEACHER CONTROLLER (permission:teachers.view / teachers.create / etc.)
GET    /api/teachers
GET    /api/teachers/{id}
POST   /api/teachers
PUT    /api/teachers/{id}
DELETE /api/teachers/{id}
PATCH  /api/teachers/{id}/status

4. BULK IMPORT SERVICE
Create app/Services/Student/BulkImportService.php:

Expected Excel columns (header row required):
| full_name | whatsapp_number | guardian_name | guardian_phone | relationship |

parseAndValidate(UploadedFile $file): array
- Parse Excel using maatwebsite/excel package
- For each row validate:
  a. full_name: required, min 2 chars
  b. guardian_phone: required, valid phone format, normalize to E.164
  c. guardian_name: required
  d. relationship: optional, default to 'parent'
- Detect duplicates: guardian_phone already exists in guardians table
- Return: { valid: [...], invalid: [{row, field, error}], duplicates: [{row, existing_id}] }

import(array $validRows, string $conflictStrategy): ImportResult
- conflictStrategy options: 'skip' | 'update'
- For each valid row:
  a. Create or find guardian by normalized phone
  b. If conflict and strategy=update: update guardian name
  c. If conflict and strategy=skip: skip row
  d. Create student with full_name
  e. Link guardian to student (is_primary=true)
  f. Log audit: student.bulk_imported
- Return: { created: N, updated: N, skipped: N, errors: [...] }

5. BULK IMPORT CONTROLLER
POST /api/students/import (multipart form, file field: students)
- Dispatch ProcessBulkImportJob::dispatch(file, auth()->id(), $conflictStrategy)
- Return: { import_id: uuid, status: 'processing', total_rows: N }

GET /api/students/import/{importId}/status
- Return current status + summary + errors list

Create app/Jobs/ProcessBulkImportJob.php (queue: low):
- Store results in cache with key "import:{uuid}"
- Update status as processing progresses

WRITE TESTS FOR:
- TeacherService::delete throws if active schedules exist
- BulkImportService: valid Excel creates students + guardians
- BulkImportService: invalid phone rejected with row + field in error
- BulkImportService: duplicate phone with skip strategy skips row
- BulkImportService: duplicate phone with update strategy updates guardian
- Import job updates status cache correctly
```

---

====================================================================
# WEEK 8 — TIMETABLE ENGINE (Schedules)
====================================================================

## BACKEND PROMPT — Week 8

```
[PASTE UNIVERSAL CONTEXT BLOCK]
[Paste current progress.md]

TODAY'S TASK: Week 8 Backend — Timetable engine (schedules + class entities)

RELEVANT SPEC: docs/data_model.md tables: schedules, class_entities, class_entity_student

1. MIGRATIONS
class_entities:
- id, name (varchar 255), description (text nullable), timestamps

class_entity_student (pivot):
- class_entity_id (FK), student_id (FK), PRIMARY(class_entity_id, student_id)

schedules:
- id, title (varchar 255), student_id (FK students nullable),
  class_entity_id (FK class_entities nullable),
  teacher_id (FK teachers), day_of_week (smallint 0-6),
  start_time (time), end_time (time), is_online (bool default false),
  meeting_link (varchar 500 nullable), location (varchar 255 nullable),
  status (enum: active/paused/stopped, default: active), timestamps, softDeletes
CHECK: (student_id IS NOT NULL OR class_entity_id IS NOT NULL) — at least one must be set
CHECK: (student_id IS NULL OR class_entity_id IS NULL) — not both
Index: teacher_id, student_id, class_entity_id, day_of_week, status

2. MODELS
Schedule: belongsTo Teacher, belongsTo Student (nullable), belongsTo ClassEntity (nullable),
  hasMany Session. Status cast to ScheduleStatus enum.
ClassEntity: belongsToMany Student (via class_entity_student), hasMany Schedule.

3. CONFLICT CHECKER SERVICE
Create app/Services/Timetable/ConflictCheckerService.php:
checkTeacherConflict(int $teacherId, int $dayOfWeek, string $startTime, string $endTime, ?int $excludeScheduleId = null): bool
- Query schedules WHERE teacher_id=$teacherId AND day_of_week=$dayOfWeek AND status=active
  AND NOT id=$excludeScheduleId
- Check time overlap: new start < existing end AND new end > existing start
- Return true if conflict found

checkSessionConflict(int $teacherId, Carbon $date, string $startTime, string $endTime, ?int $excludeSessionId = null): bool
- Same logic but on sessions table for specific date

4. SCHEDULE SERVICE
Create app/Services/Timetable/ScheduleService.php:

create(array $data, User $createdBy): Schedule
- Validate: teacher exists and is active
- Validate: either student_id or class_entity_id provided (not both)
- Validate: if online, meeting_link is required
- Check teacher conflict: ConflictCheckerService::checkTeacherConflict() → throw ConflictException if conflict
- Create and return Schedule
- Log audit

update(Schedule $schedule, array $data, User $updatedBy): Schedule
- Same validations with excludeScheduleId for conflict check
- Log audit

pause(Schedule $schedule, User $by): void   → status=paused, log audit
stop(Schedule $schedule, User $by): void    → status=stopped, log audit
delete(Schedule $schedule, User $by): void  → softDelete if no upcoming sessions

5. CLASS ENTITY SERVICE
Create app/Services/Timetable/ClassEntityService.php:
- CRUD for class entities
- addStudent(ClassEntity $entity, Student $student): attach to pivot
- removeStudent(ClassEntity $entity, Student $student): detach from pivot
- getStudents(ClassEntity $entity): return student list

6. CONTROLLERS
ScheduleController (permission:schedules.view/create/edit/delete):
GET    /api/schedules                (filter: teacher_id, student_id, class_entity_id, day, status)
POST   /api/schedules
GET    /api/schedules/{id}
PUT    /api/schedules/{id}
DELETE /api/schedules/{id}
PATCH  /api/schedules/{id}/status    {status: paused|stopped|active}
GET    /api/sessions/conflicts       (query params: teacher_id, date, start_time, end_time)

ClassEntityController:
GET    /api/class-entities
POST   /api/class-entities
PUT    /api/class-entities/{id}
DELETE /api/class-entities/{id}
POST   /api/class-entities/{id}/students   {student_ids: [...]}
DELETE /api/class-entities/{id}/students/{studentId}

WRITE TESTS FOR:
- Create schedule: overlapping time for same teacher throws ConflictException
- Create schedule: adjacent times (no overlap) succeed
- Create schedule: requires either student_id or class_entity_id
- Update schedule: excludes self from conflict check
- ClassEntity: adding/removing students correctly manages pivot
```

## FLUTTER PROMPT — Week 8

```
[PASTE UNIVERSAL CONTEXT BLOCK]
[Paste current progress.md]

TODAY'S TASK: Week 8 Flutter — Timetable screens (Admin)

1. SCHEDULE LIST SCREEN
- Toggle button: List View ↔ Weekly Calendar View
- List View: schedules grouped by day of week
  - ScheduleCard: teacher name, time, student/class-entity name, online/offline badge, status
  - Expand card to see actions (edit, pause, stop)
- Weekly Calendar View: 7 columns (days), rows = time slots (30min increments 8am-10pm)
  - Color-coded blocks per teacher
  - Tap block → schedule detail bottom sheet
- FAB: Create new schedule

2. CREATE SCHEDULE SCREEN (Stepped Form, 3 steps)
Step 1 — Basic Info:
- Session title (text field)
- Student OR Class-Entity (radio selector)
  - If Student: searchable dropdown of active students
  - If Class-Entity: searchable dropdown of class entities
- Teacher: searchable dropdown of active teachers

Step 2 — Time:
- Day of week: horizontal chip selector (السبت through الجمعة)
- Start time: time picker
- End time: time picker (min = start time + 30min)
- Real-time conflict check: after selecting teacher + day + time, call /api/sessions/conflicts
  - If conflict: show red warning card "تعارض: المعلم لديه حصة من 10:00 إلى 11:00"

Step 3 — Location:
- Online/Offline toggle
- If online: Meeting Link field
- If offline: Location/Address field
- Review summary of all selections
- "Create Schedule" button

3. CLASS ENTITIES SCREEN
- List of class entities with student count
- Tap → detail screen showing members list
- Add/remove students from class entity
- Create/edit/delete class entities

WRITE TESTS FOR:
- ScheduleBloc: conflict warning appears after time selection when conflict exists
- ScheduleBloc: conflict warning clears when different time selected
- Create schedule step navigation: Next disabled until required fields filled
```

---

====================================================================
# WEEK 9 — SESSION GENERATION + EXCEPTIONS
====================================================================

## BACKEND PROMPT — Week 9

```
[PASTE UNIVERSAL CONTEXT BLOCK]
[Paste current progress.md]

TODAY'S TASK: Week 9 Backend — Session generation, status management, exceptions

RELEVANT SPEC: docs/scheduler_and_jobs.md section 5.2, docs/data_model.md tables: sessions, session_exceptions

1. MIGRATIONS
sessions:
- id, schedule_id (FK schedules), session_date (date), start_time (time), end_time (time),
  teacher_id (FK teachers), status (enum: upcoming/done/postponed/cancelled, default: upcoming),
  is_exception (bool default false), timestamps
UNIQUE: (schedule_id, session_date)
Index: session_date, teacher_id, status

session_exceptions:
- id, session_id (FK sessions), exception_type (enum: cancel/reschedule/time_change),
  original_date (date), new_date (date nullable), new_start_time (time nullable),
  new_end_time (time nullable), reason (text nullable), created_by_id (FK users), created_at

2. SESSION GENERATOR SERVICE
Create app/Services/Timetable/SessionGeneratorService.php:

generateForDateRange(Carbon $from, Carbon $to, ?array $scheduleIds = null): GenerationResult
- Query active schedules (filtered by scheduleIds if provided)
- For each schedule, for each date in range:
  a. Check if date's day_of_week matches schedule.day_of_week
  b. If match: INSERT session with ON CONFLICT (schedule_id, session_date) DO NOTHING
  c. If teacher conflict exists (same teacher, same date, overlapping time): skip + log warning
- Return: { generated: N, skipped_duplicates: N, skipped_conflicts: N, conflicts: [...] }

3. GENERATE SESSIONS JOB
Create app/Jobs/GenerateSessionsJob.php (queue: low):
- Handle() calls SessionGeneratorService::generateForDateRange() for next week
- Runs weekly via scheduler: $schedule->job(new GenerateSessionsJob)->weeklyOn(0, '00:00')
- After generating: dispatch CreateReminderJobsJob for the generated sessions

4. SESSION SERVICE
Create app/Services/Timetable/SessionService.php:

list(array $filters): Collection — filter by date range, teacher, schedule, status

updateStatus(Session $session, string $newStatus, User $by): void
- Validate transition: upcoming→done ok, cancelled→done not ok, etc.
- Log audit: session.status_changed

cancelSession(Session $session, string $reason, User $by): void
- Set status=cancelled
- Also cancel any pending reminder_jobs for this session:
  ReminderJob::where('session_id', session)->where('status', 'pending')->update(['status' => 'cancelled'])
- Create session_exception record (type=cancel)
- Log audit

rescheduleSession(Session $session, Carbon $newDate, string $newStart, string $newEnd, User $by): void
- Check teacher conflict on new date/time
- Create new Session for new date (as exception)
- Mark original session as cancelled
- Create session_exception record (type=reschedule)
- Cancel original reminder_jobs
- Create new reminder_jobs for new date/time (via ReminderSchedulerService)
- Log audit

changeTime(Session $session, string $newStart, string $newEnd, User $by): void
- Check teacher conflict on same date with new times
- Update session start_time and end_time, set is_exception=true
- Create session_exception (type=time_change)
- Recreate reminder_jobs with new time
- Log audit

5. CONTROLLERS
SessionController (permission:sessions.view/edit):
GET    /api/sessions                    (filter: from, to, teacher_id, schedule_id, status)
GET    /api/sessions/{id}
PATCH  /api/sessions/{id}/status        {status}
POST   /api/sessions/{id}/cancel        {reason}
POST   /api/sessions/{id}/reschedule    {new_date, new_start_time, new_end_time, reason}
POST   /api/sessions/{id}/change-time   {new_start_time, new_end_time, reason}
POST   /api/schedules/generate          {from_date, to_date, schedule_ids?}

WRITE TESTS FOR:
- GenerateSessionsJob: generates correct sessions for date range
- GenerateSessionsJob: idempotent — running twice creates same sessions (no duplicates)
- GenerateSessionsJob: skips sessions with teacher conflict
- cancelSession: cancels all pending reminder_jobs for that session
- rescheduleSession: creates new session + exception record + new reminder_jobs
- Status transition: done→upcoming rejected with validation error
```

---

====================================================================
# WEEK 10 — REMINDERS
====================================================================

## BACKEND PROMPT — Week 10

```
[PASTE UNIVERSAL CONTEXT BLOCK]
[Paste current progress.md]

TODAY'S TASK: Week 10 Backend — Reminders system

RELEVANT SPEC: docs/scheduler_and_jobs.md sections 5.3, 5.4, 5.5, 5.6, 5.7

1. MIGRATIONS
reminder_policies:
- id, name (varchar 255), trigger_minutes_before (int),
  target (enum: parent/teacher/both), template_id (FK whatsapp_templates),
  is_enabled (bool default true), timestamps

reminder_jobs:
- id, reminder_policy_id (FK), session_id (FK sessions),
  scheduled_at (timestamp), recipient_number (varchar 20),
  recipient_type (enum: parent/teacher),
  status (enum: pending/sent/delivered/failed/cancelled, default: pending),
  failure_reason (text nullable), retry_count (smallint default 0),
  idempotency_key (varchar 255, UNIQUE),
  sent_at (timestamp nullable), created_at
Index: scheduled_at, status

2. REMINDER SCHEDULER SERVICE
Create app/Services/Reminder/ReminderSchedulerService.php:

createJobsForSession(Session $session): int
- Load all active reminder_policies
- For each policy:
  a. Calculate scheduled_at = session_date + session.start_time - policy.trigger_minutes_before minutes
  b. If scheduled_at is in the past: skip
  c. Determine recipients based on policy.target:
     - parent: get guardian.whatsapp_number (primary guardian)
     - teacher: get session.teacher.whatsapp_number
     - both: create 2 jobs
  d. Generate idempotency_key: "reminder:{policy_id}:{session_id}:{recipient_number}"
  e. INSERT INTO reminder_jobs ... ON CONFLICT (idempotency_key) DO NOTHING
  f. If inserted: dispatch SendReminderJob::dispatch($reminderJob)->delay($scheduledAt)
- Return count of jobs created

cancelJobsForSession(Session $session): void
- UPDATE reminder_jobs SET status=cancelled WHERE session_id=session.id AND status=pending

3. CREATE REMINDER JOBS JOB
Create app/Jobs/CreateReminderJobsJob.php (queue: low):
handle(): void
- Query sessions WHERE session_date = tomorrow AND status = upcoming
- For each session: call ReminderSchedulerService::createJobsForSession()
- Log total created
Runs daily at 00:30 via scheduler.

4. SEND REMINDER JOB
Create app/Jobs/SendReminderJob.php (queue: default):
Retry: 3, backoff: [60, 300, 600]

handle(): void
- Reload reminder_job (check it's still pending — not cancelled)
- If status != pending: return (already processed or cancelled)
- Load policy.template and resolve variables:
  student_name: session.schedule.student.full_name (or class entity name)
  session_time: format session.start_time in Arabic (09:30 صباحاً)
  teacher_name: session.teacher.full_name
  session_date: format session.session_date in Arabic
- Call WhatsAppService::sendTemplate(to, template_name, params, language)
- On success: update reminder_job.status=sent, sent_at=now()
  Create DeliveryLog record (status=sent)
- On failure (WhatsAppException): 
  increment retry_count
  If retry_count < 3: re-throw exception (Laravel will retry with backoff)
  If retry_count >= 3: set status=failed, failure_reason, create DeliveryLog(failed)

5. REMINDER POLICY CONTROLLER (permission:reminders.manage)
GET    /api/reminder-policies
POST   /api/reminder-policies     {name, trigger_minutes_before, target, template_id}
PUT    /api/reminder-policies/{id}
PATCH  /api/reminder-policies/{id}/toggle    → flip is_enabled
DELETE /api/reminder-policies/{id}

6. DELIVERY LOG CONTROLLER (permission:reminders.view)
GET    /api/reminder-jobs         (filter: status, date, session_id)
POST   /api/reminder-jobs/{id}/retry → re-queue SendReminderJob, reset status to pending

WRITE TESTS FOR:
- ReminderSchedulerService: creates correct jobs for policy.target=both (2 jobs)
- ReminderSchedulerService: idempotent (running twice creates same number of jobs)
- ReminderSchedulerService: skips past scheduled_at
- SendReminderJob: cancelled job is skipped without sending
- SendReminderJob: retries up to 3 times on WhatsAppException
- SendReminderJob: marks failed after 3rd retry failure
- cancelJobsForSession: all pending jobs become cancelled
```

## FLUTTER PROMPT — Week 10

```
[PASTE UNIVERSAL CONTEXT BLOCK]
[Paste current progress.md]

TODAY'S TASK: Week 10 Flutter — Sessions + Reminders screens (Admin)

1. SESSIONS SCREEN
- Calendar header: week selector (swipe left/right to change week)
- Below: list of sessions for selected week, grouped by day
- SessionCard:
  - Date + time, Teacher name, Student/Class name
  - Status badge: upcoming(blue)/done(green)/postponed(yellow)/cancelled(grey)
  - Tap → Session Detail bottom sheet

2. SESSION DETAIL BOTTOM SHEET
- Header: date, time, teacher
- Student/Class info
- Status badge + action buttons based on status:
  If upcoming: [Mark Done] [Postpone] [Cancel] [Change Time] [Reschedule]
  If done/cancelled: read-only info
- Cancel: shows dialog asking for reason (text field)
- Reschedule: shows date + time picker modal

3. GENERATE SESSIONS SCREEN
- Date range picker (from/to)
- Optional: select specific schedules (multi-select)
- "Generate" button → loading → result card
- Result card: Generated: 24 | Skipped (duplicate): 1 | Conflicts: 2
- Conflict list: shows which sessions were skipped + reason

4. REMINDERS SCREEN (Admin)
- Tabs: Policies | Delivery Log

Policies tab:
- List of ReminderPolicyCards:
  - Name, "X min before", target badge, template name, enabled toggle
  - Tap → edit policy bottom sheet
- FAB: Add new policy

Delivery Log tab:
- Filter chips: All | Sent | Failed | Pending | Cancelled
- List of DeliveryLogCards:
  - Session date + time, recipient number, policy name, status badge, sent_at
  - If failed: show failure reason + "Retry" button
- Pull-to-refresh

5. REMINDER POLICY FORM (bottom sheet)
- Name field
- Minutes before: numeric slider (0, 10, 15, 30, 60, 120 options as chips)
- Target: segmented control (Parent | Teacher | Both)
- Template: searchable dropdown of approved WhatsApp templates
- Preview section: show resolved template body with placeholder values

WRITE TESTS FOR:
- PolicyBloc: toggle enabled/disabled calls correct API
- SessionBloc: cancel session + reason updates session status in list
- DeliveryLogBloc: retry button dispatches retry event
- GenerateSessionsBloc: shows result summary after generation
```

---

====================================================================
# WEEK 11 — ADMIN FEATURES
====================================================================

## BACKEND PROMPT — Week 11

```
[PASTE UNIVERSAL CONTEXT BLOCK]
[Paste current progress.md]

TODAY'S TASK: Week 11 Backend — Admin: Users, Routing, Audit Log, Analytics, FCM

1. USER MANAGEMENT CONTROLLER (permission:users.*)
GET    /api/admin/users                  (filter: role, status, search)
POST   /api/admin/users                  {name, email, phone, password, role, max_open_tickets}
GET    /api/admin/users/{id}
PUT    /api/admin/users/{id}
DELETE /api/admin/users/{id}         (softDelete — cannot delete self)
GET    /api/admin/users/{id}/shifts
PUT    /api/admin/users/{id}/shifts      {shifts: [{day_of_week, start_time, end_time, is_active}]}
PUT    /api/admin/users/{id}/max-tickets {max_open_tickets: N}

2. AUDIT LOG
Create app/Services/AuditService.php:
log(string $action, Model $model, User|null $user, array $oldValues = [], array $newValues = []): void
- Insert into audit_logs (immutable — never updated)
- Include ip_address from request context

Create audit_logs migration:
- id, user_id (FK nullable), action, auditable_type, auditable_id,
  old_values (jsonb nullable), new_values (jsonb nullable),
  ip_address (varchar 45 nullable), user_agent (varchar 500 nullable),
  created_at (NO updated_at — immutable)
Index: user_id, auditable_type+auditable_id, action, created_at

AuditLogController (permission:audit.view):
GET /api/admin/audit-logs   (filter: user_id, action, auditable_type, from, to — paginated)
GET /api/admin/audit-logs/{id}

3. ANALYTICS SERVICE
Create app/Services/Analytics/AnalyticsService.php:

getOverview(): array
- tickets_open: count status NOT IN (resolved, closed) 
- tickets_today: count created_at::date = today
- avg_first_response_min: AVG(EXTRACT(EPOCH FROM sla_first_response_at - created_at)/60) WHERE sla_first_response_at IS NOT NULL
- avg_resolution_min: AVG(EXTRACT(EPOCH FROM sla_resolved_at - created_at)/60) WHERE sla_resolved_at IS NOT NULL
- sla_compliance_pct: (non-breached / total with SLA policy) * 100
- reminders_sent_today, reminders_failed_today

getSupervisorPerformance(Carbon $from, Carbon $to): array
- Per supervisor: tickets_assigned, tickets_resolved, avg_first_response, avg_resolution

getTicketsByDay(Carbon $from, Carbon $to): array — count per day
getTopTags(int $limit = 10): array — most used tags with counts
getReminderStats(Carbon $from, Carbon $to): array — sent/failed/retry rates

AnalyticsController (permission:analytics.view):
GET /api/admin/analytics/overview
GET /api/admin/analytics/tickets          ?from=&to=
GET /api/admin/analytics/sla              ?from=&to=
GET /api/admin/analytics/supervisor-performance   ?from=&to=
GET /api/admin/analytics/tags
GET /api/admin/analytics/reminders        ?from=&to=

4. PUSH NOTIFICATIONS VIA FCM
Create app/Services/Notification/PushNotificationService.php:
sendToUser(User $user, string $title, string $body, array $data = []): void
- Load user's device_sessions where expires_at > now
- For each session with fcm_token: call Firebase FCM API (POST to fcm.googleapis.com)
- Handle invalid token: remove device_session

sendToRole(string $role, ...): void
- Get all users with role, call sendToUser for each

Use in:
- TicketCreated → notify owner
- TicketEscalated → notify admin
- SlaBreached → notify owner + admin
- OverflowTicket → notify admin

Update AuthController::login to accept + store fcm_token in device_session

WRITE TESTS FOR:
- AuditService: creates correct audit_log with old/new values
- AuditLog endpoint: admin can query, supervisor gets 403
- AnalyticsService::getOverview: returns correct KPI counts
- AnalyticsService::getSupervisorPerformance: correct per-supervisor aggregates
- User management: cannot delete own account (returns 422)
- Shifts: bulk update replaces all shifts for that user
```

## FLUTTER PROMPT — Week 11

```
[PASTE UNIVERSAL CONTEXT BLOCK]
[Paste current progress.md]

TODAY'S TASK: Week 11 Flutter — Admin dashboard screens

1. ADMIN OVERVIEW SCREEN
- Header: "لوحة التحكم" with date
- KPI Cards row (horizontal scroll):
  KpiCard for: Open Tickets, Tickets Today, Avg Response (min), SLA Compliance (%),
               Reminders Sent Today, Failed Reminders Today
  Each card: icon + value + label + trend arrow (up/down vs yesterday)
- Charts section:
  - Line chart: Tickets per day (last 7 days) using fl_chart
  - Bar chart: Tickets per supervisor (top 5)
- Alert cards: Escalated tickets count, Unassigned overflow tickets, Failed reminders
  Each alert: red/amber card with count + "View" button that navigates to filtered list

2. USER MANAGEMENT SCREEN
- User list: AvatarCircle + name + role badge + availability dot + open tickets count
- Filter: role chips
- Tap → User Detail screen:
  - Edit name, phone, max_open_tickets
  - Shifts schedule: 7-day grid, each day shows shift time or "Off"
  - Tap shift cell → time picker to set/clear shift

3. ANALYTICS SCREEN
- Date range selector at top
- Tabs: Overview | Supervisors | Tags | Reminders
- Overview tab: KPI cards + line chart (tickets/day)
- Supervisors tab: ranking table with avg response + resolution times
- Tags tab: horizontal bar chart of top 10 tags
- Reminders tab: pie chart (sent/failed) + success rate

4. AUDIT LOG SCREEN
- Filter: user dropdown, action dropdown, date range
- List of AuditLogCard:
  - Action badge, user name, entity type + ID, timestamp
  - Expand to see old_values → new_values (JSON formatted, diff highlighted)

5. ADMIN TICKET LIST
- Same as supervisor Inbox but shows ALL tickets (all supervisors)
- Extra filter: "Unassigned" (overflow queue)
- Bulk actions: select multiple → bulk assign to supervisor
- Escalated tab: highlighted in red

WRITE TESTS FOR:
- AnalyticsBloc: date range change triggers new API call
- AdminOverviewBloc: alerts show non-zero values when data present
- UserManagementBloc: shift update triggers correct API call
- AuditLogBloc: filter by action correctly filters list
```

---

====================================================================
# WEEK 12 — TESTING + LAUNCH PREP
====================================================================

## PROMPT — Week 12 Final Testing + Polish

```
[PASTE UNIVERSAL CONTEXT BLOCK]
[Paste current progress.md]

TODAY'S TASK: Week 12 — Final integration tests, E2E flows, bug fixes, launch prep

1. INTEGRATION TESTS TO WRITE (Backend)
Write complete PHPUnit Feature tests for these full flows:

Test 1: Full Ticket Lifecycle
- Setup: create guardian + student in DB
- POST webhook with inbound message → ticket created (status=new)
- Backend routes to supervisor (round robin)
- Supervisor replies → message sent, sla_first_response_at set
- Supervisor marks pending
- Supervisor resolves with reason
- Admin closes ticket
- Verify audit_log has entry for each action
- Verify WhatsApp message count = 2 (inbound + outbound)

Test 2: Webhook Idempotency
- POST same webhook payload twice (same wamid)
- Assert: only 1 WhatsappMessage record in DB
- Assert: only 1 Ticket record created
- Assert: second request returns 200 without error

Test 3: SLA Breach Detection
- Create ticket with SLA policy (first_response = 2 minutes)
- Travel time forward 3 minutes (use Carbon::setTestNow())
- Run CheckSlaBreachJob manually
- Assert ticket.sla_breached = true
- Assert if auto_escalate=true: ticket.status = escalated

Test 4: Reminder Dedupe
- Create session for tomorrow
- Run CreateReminderJobsJob twice
- Assert: reminder_jobs count = same as after first run (no duplicates)
- Assert: idempotency_keys are unique

Test 5: Session Generation Dedupe
- Run GenerateSessionsJob twice for same week
- Assert: sessions count = same after second run
- Assert: no duplicate (schedule_id, session_date) pairs

Test 6: RBAC Enforcement
- Login as supervisor → try GET /api/admin/users → assert 403
- Login as admin → GET /api/admin/users → assert 200
- Login as supervisor → GET /api/tickets → assert 200

Test 7: Overflow Routing
- Create 3 supervisors each with max_open_tickets = 1
- Create 3 open tickets for each supervisor (filling them)
- POST new inbound webhook
- Assert: new ticket.owner_id = null (overflow to admin queue)

Test 8: Sticky Owner
- Create guardian + 2 supervisors
- First ticket → assigned to Supervisor A → resolved
- Second inbound message from same guardian (within 30 days)
- Assert: new ticket assigned to Supervisor A (not B)

2. FLUTTER E2E TESTS (integration_test/)
Write these flows:

E2E 1: Login Flow
- Launch app
- Enter valid credentials
- Assert routed to correct dashboard based on role

E2E 2: Ticket Reply
- Navigate to inbox
- Tap first ticket
- Type reply message
- Assert message bubble appears in chat

E2E 3: Session Cancellation
- Navigate to Sessions
- Tap a session
- Tap Cancel → enter reason → confirm
- Assert session status changes to Cancelled in list

3. SWAGGER / API DOCUMENTATION
Install darkaonline/l5-swagger
Add @OA annotations to all controllers
Generate docs: php artisan l5-swagger:generate
Verify all endpoints documented at /api/documentation

4. DOCKER PRODUCTION CONFIG
Create Dockerfile (multi-stage):
Stage 1: composer install --no-dev
Stage 2: nginx + php-fpm optimized
Environment variables: all via .env (no hardcoded values)

Create docker-compose.prod.yml with:
- app: production image
- nginx
- postgres (separate volume)
- redis
- queue (2 workers: high queue)
- scheduler

5. DEPLOYMENT CHECKLIST
Before going live, verify:
[ ] APP_ENV=production, APP_DEBUG=false
[ ] Database migrations run successfully
[ ] Seeders run (roles, permissions, default SLA policies)
[ ] WhatsApp webhook URL registered with BSP
[ ] FCM credentials configured
[ ] S3 storage configured and writable
[ ] SSL certificate active (HTTPS only)
[ ] Queue workers running and processing
[ ] Scheduler running (cron or schedule:work)
[ ] Reverb WebSocket server running
[ ] Sentry DSN configured for both Laravel and Flutter

6. BUG FIX PROCESS
For any failing test discovered this week, use this prompt:

"The following test is failing:
[paste test name + error output]

Here is the relevant service code:
[paste current code]

Fix the bug while:
- Keeping business logic in the Service (not controller)
- Using the correct enum for status values  
- Maintaining all existing passing tests
- Adding a comment explaining why the bug occurred"
```

---

====================================================================
# POST-MVP: V1 PROMPTS (Month 4+)
====================================================================

## ANALYTICS DEEP DIVE PROMPT

```
[PASTE UNIVERSAL CONTEXT BLOCK]

TODAY'S TASK: V1 — Advanced Analytics

Add these analytics endpoints + Flutter screens:
1. Export CSV: GET /api/admin/analytics/export?type=tickets&from=&to= 
   Returns CSV download of all ticket data for date range
2. SLA breakdown: per-tag SLA compliance (which tag breaches most)
3. Supervisor workload heatmap: tickets per hour-of-day per supervisor
4. Guardian interaction report: guardians sorted by most tickets opened

Flutter: Add "Export" button to analytics screen using url_launcher to open CSV download URL
```

## OFFLINE MODE PROMPT

```
[PASTE UNIVERSAL CONTEXT BLOCK]

TODAY'S TASK: V1 — Offline mode for Flutter app

1. Cache last 50 tickets in Hive when online
2. Cache ticket details + messages when opened
3. When offline: show cached inbox with "Offline" banner
4. Queue actions when offline: {type: 'reply', ticketId: X, content: Y}
5. On reconnect: process queued actions in order, show sync status
6. Conflict resolution: if server state changed while offline, show conflict dialog

Use packages: hive_flutter for local storage, connectivity_plus for network detection
Show "Last synced: 5 min ago" in offline banner
```

## ADVANCED SEARCH PROMPT

```
[PASTE UNIVERSAL CONTEXT BLOCK]

TODAY'S TASK: V1 — Full-text search

Backend:
1. Add PostgreSQL tsvector column to tickets (search_vector) with trigger to auto-update
   Include: ticket_number, guardian name, student name, last message preview
2. Add search index: CREATE INDEX tickets_search_idx ON tickets USING GIN(search_vector)
3. GET /api/search?q=keyword&types=tickets,students,guardians
   Returns unified results from all entity types

Flutter:
1. Global search screen accessible via search icon in any dashboard AppBar
2. Unified results list grouped by type: Tickets (3) | Students (2) | Teachers (1)
3. Highlight matched terms in result cards
4. Debounce 300ms, minimum 3 characters
5. Recent searches stored in Hive (last 10)
```
