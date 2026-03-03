# 3. Complete API Specification

> **Base URL**: `https://api.almajd.academy/api/v1`
> **Auth**: Bearer JWT on all endpoints except `/auth/login` and `/webhooks/*`
> **Response envelope**: `{ "success": bool, "data": {}, "message": "", "meta": {} }`

## 3.1 Auth

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/auth/login` | Login with email+password, returns JWT+refresh |
| POST | `/auth/refresh` | Refresh JWT using refresh token |
| POST | `/auth/logout` | Invalidate current token + device session |
| GET | `/auth/me` | Get current user profile + permissions |
| PUT | `/auth/me` | Update profile (name, avatar) |
| PUT | `/auth/me/password` | Change password |
| PUT | `/auth/me/availability` | Set availability status |

**Login Request/Response:**
```json
// POST /auth/login
{ "email": "sup@almajd.com", "password": "...", "device_id": "abc123", "device_name": "iPhone 15", "fcm_token": "..." }

// Response 200
{ "success": true, "data": {
    "access_token": "eyJ...", "refresh_token": "...", "expires_in": 900,
    "user": { "id": 1, "name": "أحمد", "email": "...", "roles": ["supervisor"], "permissions": ["tickets.view","tickets.reply"] }
}}
```

## 3.2 Users & Roles (Admin)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/admin/users` | List users (paginated, filter by role/status) |
| POST | `/admin/users` | Create user |
| GET | `/admin/users/{id}` | Get user details |
| PUT | `/admin/users/{id}` | Update user |
| DELETE | `/admin/users/{id}` | Soft-delete user |
| GET | `/admin/roles` | List roles with permissions |
| POST | `/admin/roles` | Create custom role |
| PUT | `/admin/roles/{id}` | Update role permissions |
| GET | `/admin/users/{id}/shifts` | Get user shifts |
| PUT | `/admin/users/{id}/shifts` | Update user shifts (bulk) |

## 3.3 Tickets

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/tickets` | List tickets (filter: status, owner, priority, tags, search) |
| GET | `/tickets/{id}` | Get ticket with messages + notes |
| POST | `/tickets/{id}/assign` | Assign/reassign ticket |
| POST | `/tickets/{id}/reply` | Send reply via WhatsApp |
| POST | `/tickets/{id}/status` | Change status (pending/resolved/closed) |
| POST | `/tickets/{id}/escalate` | Escalate ticket with reason |
| POST | `/tickets/{id}/notes` | Add internal note |
| POST | `/tickets/{id}/follow-up` | Set follow-up reminder |
| GET | `/tickets/{id}/messages` | Get all WhatsApp messages for ticket |
| GET | `/tickets/{id}/timeline` | Get audit trail for ticket |

**Ticket List Response:**
```json
{ "success": true, "data": [
  { "id": 1, "ticket_number": "TKT-20260302-0001", "status": "new", "priority": "high",
    "owner": { "id": 2, "name": "أحمد" },
    "guardian": { "id": 5, "name": "محمد", "whatsapp": "+966501234567" },
    "student": { "id": 10, "name": "سارة" },
    "tags": [{ "id": 1, "name": "payment", "color": "#FF5722" }],
    "sla": { "first_response_due_at": "2026-03-02T02:28:00Z", "breached": false, "remaining_seconds": 180 },
    "last_message_preview": "السلام عليكم، أريد الاستفسار...",
    "created_at": "2026-03-02T02:23:00Z", "updated_at": "2026-03-02T02:23:00Z" }
], "meta": { "current_page": 1, "per_page": 20, "total": 150 }}
```

**Reply Request:**
```json
// POST /tickets/{id}/reply
{ "content": "شكراً لتواصلكم...", "type": "text" }
// For media: multipart/form-data with file + content
```

## 3.4 Students & Guardians

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/students` | List students (filter: status, search, guardian) |
| POST | `/students` | Create student |
| GET | `/students/{id}` | Get student with guardians + timeline |
| PUT | `/students/{id}` | Update student |
| DELETE | `/students/{id}` | Soft-delete (set status=dropped) |
| GET | `/students/{id}/timeline` | Messages, notes, sessions |
| POST | `/students/{id}/notes` | Add internal note |
| GET | `/guardians` | List guardians |
| POST | `/guardians` | Create guardian |
| PUT | `/guardians/{id}` | Update guardian |
| POST | `/guardians/{id}/students` | Link guardian to student |
| POST | `/students/import` | Bulk import from Excel |
| GET | `/students/import/{id}/status` | Check import job status |

**Bulk Import Request:**
```json
// POST /students/import (multipart/form-data)
// file: students.xlsx
// Response: { "data": { "import_id": "uuid", "status": "processing", "total_rows": 150 } }

// GET /students/import/{id}/status
{ "data": { "import_id": "uuid", "status": "completed",
  "summary": { "total": 150, "created": 140, "skipped": 8, "errors": 2 },
  "errors": [{ "row": 45, "field": "whatsapp", "message": "Invalid format" }] }}
```

## 3.5 Teachers

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/teachers` | List teachers (filter: status) |
| POST | `/teachers` | Create teacher |
| GET | `/teachers/{id}` | Get teacher details |
| PUT | `/teachers/{id}` | Update teacher |
| DELETE | `/teachers/{id}` | Soft-delete |

## 3.6 Schedules & Sessions

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/schedules` | List schedules (filter: teacher, student, day) |
| POST | `/schedules` | Create recurring schedule |
| GET | `/schedules/{id}` | Get schedule details |
| PUT | `/schedules/{id}` | Update schedule |
| DELETE | `/schedules/{id}` | Delete schedule |
| POST | `/schedules/generate` | Generate sessions for date range |
| GET | `/sessions` | List sessions (filter: date range, teacher, status) |
| GET | `/sessions/{id}` | Get session details |
| PUT | `/sessions/{id}/status` | Update session status |
| POST | `/sessions/{id}/cancel` | Cancel specific session |
| POST | `/sessions/{id}/reschedule` | Reschedule to new date/time |
| GET | `/sessions/conflicts` | Check for conflicts (query: teacher_id, date, time) |

**Create Schedule:**
```json
// POST /schedules
{ "title": "حصة القرآن", "student_id": 10, "teacher_id": 3,
  "day_of_week": 1, "start_time": "10:00", "end_time": "11:00",
  "is_online": true, "meeting_link": "https://zoom.us/j/..." }
```

**Generate Sessions:**
```json
// POST /schedules/generate
{ "from_date": "2026-03-02", "to_date": "2026-03-31", "schedule_ids": [1,2,3] }
// Response: { "data": { "generated": 24, "skipped_conflicts": 2, "skipped_duplicates": 1 } }
```

## 3.7 Reminders & Templates

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/reminder-policies` | List reminder policies |
| POST | `/reminder-policies` | Create policy |
| PUT | `/reminder-policies/{id}` | Update policy |
| PUT | `/reminder-policies/{id}/toggle` | Enable/disable |
| GET | `/reminder-jobs` | List reminder jobs (filter: status, date) |
| POST | `/reminder-jobs/{id}/retry` | Retry failed reminder |
| GET | `/templates` | List WhatsApp templates |
| POST | `/templates` | Register new template |
| PUT | `/templates/{id}` | Update template |

## 3.8 Routing Rules (Admin)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/admin/routing-rules` | List routing rules |
| POST | `/admin/routing-rules` | Create rule |
| PUT | `/admin/routing-rules/{id}` | Update rule |
| DELETE | `/admin/routing-rules/{id}` | Delete rule |
| PUT | `/admin/routing-rules/reorder` | Reorder rule priorities |

**Create Routing Rule:**
```json
// POST /admin/routing-rules
{ "name": "Payment tickets to senior team", "algorithm": "least_load",
  "priority": 1, "conditions": { "tags": ["payment"], "time_range": "09:00-17:00" },
  "target_user_ids": [1, 2, 5], "is_active": true }
```

## 3.9 SLA Policies (Admin)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/admin/sla-policies` | List SLA policies |
| POST | `/admin/sla-policies` | Create SLA policy |
| PUT | `/admin/sla-policies/{id}` | Update SLA policy |
| DELETE | `/admin/sla-policies/{id}` | Delete SLA policy |

## 3.10 Audit Log

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/admin/audit-logs` | List logs (filter: user, action, entity, date range) |
| GET | `/admin/audit-logs/{id}` | Get log detail with old/new values |

## 3.11 Analytics (Admin)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/admin/analytics/overview` | Dashboard KPIs |
| GET | `/admin/analytics/tickets` | Ticket stats (opened/closed/day, by supervisor) |
| GET | `/admin/analytics/sla` | SLA compliance rates |
| GET | `/admin/analytics/response-times` | Avg first response + resolution per supervisor |
| GET | `/admin/analytics/tags` | Top tags/reasons |
| GET | `/admin/analytics/reminders` | Reminder success/failure rates |

**Overview Response:**
```json
{ "data": {
  "tickets_open": 45, "tickets_today": 12, "avg_first_response_min": 3.2,
  "avg_resolution_min": 18.5, "sla_compliance_pct": 94.5,
  "reminders_sent_today": 85, "reminders_failed_today": 3 }}
```

## 3.12 Webhooks (Inbound)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/webhooks/whatsapp` | Inbound message webhook (BSP sends here) |
| POST | `/webhooks/whatsapp/status` | Delivery status callback |
| GET | `/webhooks/whatsapp/verify` | BSP verification challenge |

## 3.13 Class Entities (Admin)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/class-entities` | List class entities |
| POST | `/class-entities` | Create class entity |
| PUT | `/class-entities/{id}` | Update class entity |
| DELETE | `/class-entities/{id}` | Delete class entity |
| POST | `/class-entities/{id}/students` | Add students to entity |
| DELETE | `/class-entities/{id}/students/{studentId}` | Remove student |

## 3.14 Pagination & Filtering Convention

All list endpoints support:
- `?page=1&per_page=20` — pagination
- `?search=query` — full-text search
- `?sort=created_at&order=desc` — sorting
- `?filter[status]=new,assigned` — field filters
- `?include=guardian,student,tags` — eager-load relations
