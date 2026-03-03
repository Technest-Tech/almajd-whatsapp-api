# 1. System Architecture & Module Breakdown

## 1.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                     EXTERNAL SERVICES                               │
│  ┌──────────────┐  ┌───────────────┐  ┌──────────────────────────┐ │
│  │ WhatsApp BSP │  │ Firebase FCM  │  │ Object Storage (S3/Min)  │ │
│  │ (360dialog/  │  │ (Push Notif)  │  │ (Media files)            │ │
│  │  Twilio)     │  │               │  │                          │ │
│  └──────┬───────┘  └───────┬───────┘  └────────────┬─────────────┘ │
└─────────┼──────────────────┼───────────────────────┼───────────────┘
          │ webhooks/API     │                       │
┌─────────▼──────────────────▼───────────────────────▼───────────────┐
│                      LARAVEL BACKEND                                │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ Presentation Layer (API Controllers + Webhook Handlers)     │   │
│  ├─────────────────────────────────────────────────────────────┤   │
│  │ Application Layer (Services + Use Cases)                    │   │
│  ├─────────────────────────────────────────────────────────────┤   │
│  │ Domain Layer (Models + Business Rules + Events)             │   │
│  ├─────────────────────────────────────────────────────────────┤   │
│  │ Infrastructure (DB + Queue + Cache + WhatsApp Provider)     │   │
│  └─────────────────────────────────────────────────────────────┘   │
│  ┌──────────┐ ┌──────────┐ ┌───────────┐ ┌───────────────────┐    │
│  │PostgreSQL│ │  Redis   │ │ Queue     │ │ WebSocket Server  │    │
│  │ (Data)   │ │ (Cache/  │ │ (Jobs/    │ │ (Laravel Reverb / │    │
│  │          │ │  Locks)  │ │  Sched.)  │ │  Pusher)          │    │
│  └──────────┘ └──────────┘ └───────────┘ └───────────────────┘    │
└────────────────────────────────┬───────────────────────────────────┘
                                 │ REST API + WebSockets
┌────────────────────────────────▼───────────────────────────────────┐
│                      FLUTTER MOBILE APP                            │
│  ┌────────────────┐ ┌────────────────┐ ┌────────────────────────┐ │
│  │ Supervisor     │ │ Sr. Supervisor │ │ Admin Dashboard        │ │
│  │ Dashboard      │ │ Dashboard      │ │                        │ │
│  └────────────────┘ └────────────────┘ └────────────────────────┘ │
│  Shared: Auth · Chat · Tickets · Search · Notifications           │
└───────────────────────────────────────────────────────────────────┘
```

## 1.2 Module Breakdown

| Module | Description | Key Entities |
|--------|-------------|-------------|
| **A. WhatsApp Integration** | BSP webhook handling, inbound/outbound, delivery tracking | `whatsapp_messages`, `whatsapp_templates`, `delivery_logs` |
| **B. Ticketing** | Ticket lifecycle, assignment, escalation, SLA | `tickets`, `ticket_notes`, `ticket_tags` |
| **C. Students CRM** | Student & guardian CRUD, timeline, bulk import | `students`, `guardians`, `student_notes` |
| **D. Teachers** | Teacher CRUD, status management | `teachers` |
| **E. Timetables** | Recurring schedules, session generation, exceptions | `schedules`, `sessions`, `session_exceptions` |
| **F. Reminders** | Template-based reminders, delivery, retry | `reminder_policies`, `reminder_jobs` |
| **G. Users & Roles** | RBAC, shifts, availability | `users`, `roles`, `permissions`, `shifts` |
| **H. Routing** | Ticket assignment, sticky owner, overflow | `routing_rules` |
| **I. Escalation** | Escalation workflow, admin takeover | Part of `tickets` |
| **J. SLA** | SLA policies, breach detection, auto-escalation | `sla_policies` |
| **K. Audit Log** | Immutable action logging | `audit_logs` |
| **L. Analytics** | KPIs, response times, SLA compliance | Computed views |

## 1.3 Laravel Backend Directory Structure

```
Almajd-Whatsapp-ApiApp/
├── app/
│   ├── Http/
│   │   ├── Controllers/
│   │   │   ├── Auth/AuthController.php
│   │   │   ├── Webhook/WhatsAppWebhookController.php
│   │   │   ├── Ticket/TicketController.php, TicketNoteController.php
│   │   │   ├── Student/StudentController, GuardianController, BulkImportController
│   │   │   ├── Teacher/TeacherController.php
│   │   │   ├── Timetable/ScheduleController, SessionController, SessionExceptionController
│   │   │   ├── Reminder/ReminderPolicyController, DeliveryLogController
│   │   │   ├── Admin/UserController, RoleController, RoutingRuleController,
│   │   │   │       SlaPolicyController, AnalyticsController
│   │   │   └── Messaging/MessageController, TemplateController
│   │   ├── Middleware/
│   │   │   ├── RoleMiddleware.php
│   │   │   ├── PermissionMiddleware.php
│   │   │   ├── WebhookSignatureMiddleware.php
│   │   │   └── IdempotencyMiddleware.php
│   │   └── Requests/              # Form Request validation per endpoint
│   ├── Models/                    # 1 Eloquent model per table
│   ├── Services/
│   │   ├── WhatsApp/              # WhatsAppServiceInterface + BSP impls
│   │   ├── Ticket/                # TicketService, RoutingService, SlaService, EscalationService
│   │   ├── Student/               # StudentService, GuardianService, BulkImportService
│   │   ├── Timetable/             # ScheduleService, SessionGeneratorService, ConflictChecker
│   │   ├── Reminder/              # ReminderService, ReminderSchedulerService
│   │   ├── Routing/               # RoutingEngine + Strategy pattern impls
│   │   └── Analytics/             # AnalyticsService
│   ├── Jobs/                      # Async queue jobs
│   ├── Events/ + Listeners/       # Domain events
│   ├── Observers/                 # Model lifecycle hooks
│   ├── Enums/                     # PHP 8.1 backed enums
│   ├── Policies/                  # Authorization
│   └── Exceptions/
├── config/ (whatsapp.php, sla.php, routing.php, reminders.php)
├── database/ (migrations/, seeders/, factories/)
├── routes/ (api.php, channels.php)
├── tests/ (Unit/, Feature/, Integration/)
├── docker-compose.yml
└── .env.example
```

## 1.4 Layer Responsibilities

| Layer | Responsibility | Rules |
|-------|---------------|-------|
| **Controllers** | HTTP I/O, validation, response formatting | Zero business logic |
| **Services** | Business rules, orchestration, events | Single-responsibility per service |
| **Models** | Relationships, scopes, accessors | No business logic |
| **Jobs** | Async processing (WhatsApp, sessions, reminders) | Retryable, idempotent |
| **Observers** | Model event side-effects | Lightweight, dispatch jobs |

## 1.5 WhatsApp Integration Design

### Inbound Flow
```
WhatsApp → BSP → POST /api/webhooks/whatsapp → Verify Signature
  → IdempotencyMiddleware (dedupe by wamid)
  → ProcessInboundMessageJob (queued):
      1. Store message in whatsapp_messages
      2. Resolve contact → find guardian → find student
      3. Find or create Ticket (sticky owner check)
      4. Route ticket if new (TicketRoutingService)
      5. Start SLA timer
      6. Broadcast real-time update via WebSocket
```

### Outbound Flow
```
Supervisor replies → POST /api/tickets/{id}/reply
  → TicketService::reply()
  → SendWhatsAppMessageJob (queued):
      1. Check 24h session window
      2. Within window → free-form message
      3. Outside window → approved template
      4. Store with delivery_status = 'scheduled'
      5. BSP callback updates → sent/delivered/failed
      6. On failure → retry w/ exponential backoff (max 3)
```

### Idempotency Strategy
- Inbound: dedupe by `wamid` via Redis lock `wa:idempotent:{wamid}` (60s TTL) + DB unique constraint
- Outbound: dedupe by `idempotency_key` per reminder/auto-message

## 1.6 Realtime Updates
- **Tech**: Laravel Reverb (built-in WebSocket) or Pusher
- **Channels**: `private-user.{userId}`, `private-admin`, `presence-supervisors`
- **Flutter**: `web_socket_channel` package

## 1.7 Security

| Concern | Solution |
|---------|----------|
| Auth | JWT (`tymon/jwt-auth`): access 15min + refresh 7d |
| Device sessions | `device_sessions` table with device_id, FCM token |
| RBAC | Spatie `laravel-permission` |
| Webhook auth | HMAC signature verification |
| Rate limiting | 60/min auth, 10/min webhooks |
| Input validation | Form Requests on every endpoint |
| Encryption | Sensitive fields encrypted at rest |
