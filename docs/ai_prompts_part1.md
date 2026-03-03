# AI Prompts — Part 1 (Weeks 1–6)
# Academy WhatsApp Communication & Operations System

====================================================================
# WEEK 1 — PROJECT SETUP & AUTH
====================================================================

## BACKEND PROMPT — Week 1

```
[PASTE UNIVERSAL CONTEXT BLOCK FROM ai_implementation_guide.md]

TODAY'S TASK: Week 1 Backend — Laravel project setup, Docker, Auth, RBAC

REQUIREMENTS:
Set up the complete Laravel 11 backend project from scratch:

1. DOCKER COMPOSE
Create docker-compose.yml with these services:
- app: PHP 8.2 FPM, mounts ./backend
- nginx: reverse proxy to app, expose port 8000
- postgres: PostgreSQL 15, DB=almajd, user=almajd, password=secret
- redis: Redis 7
- queue: runs `php artisan queue:work --queue=high,default,low`
- scheduler: runs `php artisan schedule:work`
- reverb: runs `php artisan reverb:start`

2. LARAVEL SETUP
Install these packages:
- tymon/jwt-auth (JWT authentication)
- spatie/laravel-permission (RBAC)
- laravel/reverb (WebSockets)
- barryvdh/laravel-telescope (dev only)

3. DATABASE MIGRATIONS (create in this order):
Migration 1: users table
Columns: id, name, email (unique), phone, password, avatar_url (nullable),
availability (enum: available/busy/unavailable, default: available),
max_open_tickets (int, default: 20), email_verified_at, remember_token,
timestamps, softDeletes

Migration 2: device_sessions table
Columns: id, user_id (FK users), device_id (varchar 255), device_name,
fcm_token (nullable), refresh_token, last_active_at, expires_at, created_at
UNIQUE: (user_id, device_id)

Migration 3: shifts table
Columns: id, user_id (FK users), day_of_week (smallint 0-6),
start_time (time), end_time (time), is_active (bool default true)
UNIQUE: (user_id, day_of_week)

4. ELOQUENT MODELS: User, DeviceSession, Shift
- User model: HasRoles (Spatie), HasMany DeviceSessions, HasMany Shifts
- Availability should be a backed enum: app/Enums/UserAvailability.php
- User model must cast availability to UserAvailability enum

5. AUTH SYSTEM
Create AuthController with these methods:
- login(LoginRequest $request): validate email/password, generate JWT (15min),
  generate refresh token (7 days), store device_session, return both tokens + user with roles/permissions
- refresh(RefreshRequest $request): validate refresh token from device_sessions,
  generate new JWT, update device_session.last_active_at
- logout(Request $request): delete current device_session, invalidate JWT
- me(Request $request): return authenticated user with roles, permissions, shifts

Create Form Requests: LoginRequest, RefreshRequest

6. RBAC SETUP
Create a seeder (RolesAndPermissionsSeeder) that creates:

Roles: supervisor, senior_supervisor, admin

Permissions (create all of these):
tickets.view, tickets.create, tickets.reply, tickets.assign,
tickets.escalate, tickets.resolve, tickets.close,
students.view, students.create, students.edit, students.delete,
teachers.view, teachers.create, teachers.edit, teachers.delete,
schedules.view, schedules.create, schedules.edit, schedules.delete,
sessions.view, sessions.edit,
reminders.view, reminders.manage,
users.view, users.create, users.edit, users.delete,
routing.manage, sla.manage, analytics.view, audit.view

Assign permissions to roles:
- supervisor: tickets.* (all), students.view, schedules.view, sessions.view
- senior_supervisor: everything supervisor has + analytics.view, users.view
- admin: ALL permissions

7. ROUTES (routes/api.php)
Public routes (no auth):
POST /api/auth/login
POST /api/auth/refresh

Protected routes (jwt.auth middleware):
POST /api/auth/logout
GET  /api/auth/me
PUT  /api/auth/me
PUT  /api/auth/me/availability

8. RESPONSE FORMAT
Create app/Services/ApiResponseService.php:
- success($data, $message = 'OK', $meta = [], $code = 200)
- error($message, $errors = [], $code = 400)
- All controllers must use this service for responses

WRITE FEATURE TESTS FOR:
- Login with valid credentials returns JWT + refresh token + user with roles
- Login with invalid credentials returns 401
- Refresh with valid refresh token returns new JWT
- Refresh with expired/invalid token returns 401
- Me endpoint returns user + permissions
- Logout deletes device session
- Availability update persists correctly
```

---

## FLUTTER PROMPT — Week 1

```
[PASTE UNIVERSAL CONTEXT BLOCK]

TODAY'S TASK: Week 1 Flutter — Project setup, auth, theme, navigation

Create the Flutter project at: mobile/

1. PROJECT SETUP
Initialize Flutter project with this folder structure:
lib/
├── core/
│   ├── api/
│   │   ├── api_client.dart         (Dio setup with base URL, timeout)
│   │   ├── api_interceptors.dart   (JWT interceptor, refresh interceptor, error interceptor)
│   │   └── api_response.dart       (typed response wrapper)
│   ├── auth/
│   │   ├── auth_bloc.dart
│   │   ├── auth_event.dart
│   │   ├── auth_state.dart
│   │   └── token_storage.dart      (flutter_secure_storage)
│   ├── di/
│   │   └── injection.dart          (GetIt + injectable setup)
│   ├── router/
│   │   └── app_router.dart         (GoRouter with auth + role guards)
│   ├── theme/
│   │   ├── app_theme.dart          (light + dark Material 3 themes)
│   │   ├── app_colors.dart         (primary #00897B, accent #FFA000, error #FF5252)
│   │   └── app_typography.dart     (Cairo font for Arabic, Inter for numbers)
│   ├── l10n/
│   │   ├── app_ar.arb
│   │   └── app_en.arb
│   └── widgets/
│       ├── app_button.dart         (primary, secondary, danger styles)
│       ├── app_text_field.dart     (with label, hint, validation)
│       └── loading_overlay.dart    
│
└── features/
    └── auth/
        ├── data/
        │   ├── auth_repository.dart
        │   └── auth_remote_datasource.dart
        ├── domain/
        │   ├── user_entity.dart     (freezed)
        │   └── login_usecase.dart
        └── presentation/
            ├── login_screen.dart
            └── bloc/               (auth bloc)

2. PACKAGES (pubspec.yaml)
Add:
flutter_bloc: ^8.1.6
get_it: ^7.7.0
injectable: ^2.4.4
go_router: ^14.0.0
dio: ^5.7.0
flutter_secure_storage: ^9.2.2
freezed: ^2.5.7
freezed_annotation: ^2.4.4
json_serializable: ^6.8.0
google_fonts: ^6.2.1
cached_network_image: ^3.4.1
web_socket_channel: ^3.0.1
firebase_messaging: ^15.1.4
hive_flutter: ^1.1.0
intl: any

3. THEME
Create Material 3 theme:
- Primary: #00897B (Deep Teal)
- Secondary: #FFA000 (Amber)  
- Error: #FF5252 (Coral)
- Font: Cairo for Arabic text, Inter for Latin/numbers
- Default Locale: Arabic (RTL)
- Support both light and dark mode
- Card radius: 12dp, BottomSheet radius: 24dp

4. AUTH BLOC
States: AuthInitial, AuthLoading, AuthAuthenticated(user), AuthUnauthenticated, AuthError(message)
Events: AppStarted, LoginRequested(email, password, deviceId, fcmToken), LogoutRequested, TokenRefreshed

On AppStarted: check if valid JWT in secure storage → emit Authenticated or Unauthenticated
On LoginRequested: call AuthRemoteDataSource.login() → store tokens → emit Authenticated
On LogoutRequested: call logout API → clear storage → emit Unauthenticated

5. LOGIN SCREEN
- Academy logo at top (placeholder icon for now)
- Email field with Arabic label "البريد الإلكتروني"
- Password field with show/hide toggle and Arab label "كلمة المرور"
- Login button (full width, primary color)
- Loading state: disable button, show CircularProgressIndicator inside button
- Error state: show SnackBar with error message
- All text RTL aligned

6. ROUTER
GoRouter with routes:
- /login → LoginScreen (redirect to dashboard if already authenticated)
- /supervisor → SupervisorDashboard (role guard: supervisor or senior_supervisor)
- /admin → AdminDashboard (role guard: admin)
After login, check user.roles[0] and redirect to correct dashboard

WRITE TESTS FOR:
- AuthBloc: AppStarted with stored token → AuthAuthenticated
- AuthBloc: LoginRequested with valid creds → AuthAuthenticated  
- AuthBloc: LoginRequested with wrong creds → AuthError
- AuthBloc: LogoutRequested → AuthUnauthenticated
- LoginScreen: shows form, submit triggers bloc event
```

---

====================================================================
# WEEK 2 — CORE INFRASTRUCTURE
====================================================================

## BACKEND PROMPT — Week 2

```
[PASTE UNIVERSAL CONTEXT BLOCK]
[Paste current progress.md]

TODAY'S TASK: Week 2 Backend — Middleware, API standards, WebSockets

1. MIDDLEWARE

Create app/Http/Middleware/RoleMiddleware.php:
- Accepts comma-separated roles: route::('role:admin,supervisor')
- Checks if authenticated user has any of the listed roles
- Returns 403 JSON if not authorized

Create app/Http/Middleware/PermissionMiddleware.php:
- Accepts permission name: route::('permission:tickets.view')
- Returns 403 JSON if user lacks permission

Create app/Http/Middleware/WebhookSignatureMiddleware.php:
- Reads X-Hub-Signature-256 header
- Computes HMAC SHA256 of request body using config('whatsapp.webhook_secret')
- Returns 401 if signature doesn't match

Create app/Http/Middleware/IdempotencyMiddleware.php:
- Only applies to POST /api/webhooks/whatsapp
- Reads wamid from request body: request.entry[0].changes[0].value.messages[0].id
- Checks Redis key: "wa:idempotent:{wamid}" with 60s TTL
- If key exists: return 200 OK immediately (already processed)
- If not: acquire Redis lock, set key, allow request through

2. GLOBAL ERROR HANDLING
Create app/Exceptions/Handler.php (override):
- ValidationException → 422 with errors object
- AuthenticationException → 401 
- AuthorizationException → 403
- ModelNotFoundException → 404
- ThrottleRequestsException → 429
- All others → 500 (log full exception, return generic message)
All responses use ApiResponseService format.

3. API RATE LIMITING (routes/api.php)
- Authenticated endpoints: 60 requests/minute per user
- Webhook endpoints: 200 requests/minute per IP (BSP sends many)
- Auth endpoints: 10 requests/minute per IP (brute force protection)

4. LARAVEL REVERB WEBSOCKETS
Configure config/broadcasting.php for Reverb.
Create channel definitions in routes/channels.php:
- Broadcast::channel('user.{userId}', fn($user, $userId) => $user->id == $userId)
- Broadcast::channel('admin', fn($user) => $user->hasRole('admin'))
- Broadcast::channel('supervisors', fn($user) => $user->hasAnyRole(['supervisor','senior_supervisor','admin']))

Create base event: app/Events/BaseRealtimeEvent.php (implements ShouldBroadcast)

5. CONFIG FILES
Create config/whatsapp.php:
return [
  'provider' => env('WHATSAPP_PROVIDER', 'twilio'),
  'twilio' => [
    'account_sid' => env('TWILIO_ACCOUNT_SID'),
    'auth_token' => env('TWILIO_AUTH_TOKEN'),
    'from_number' => env('TWILIO_WHATSAPP_NUMBER'),
  ],
  'webhook_secret' => env('WHATSAPP_WEBHOOK_SECRET'),
  'session_window_hours' => 24,
];

Create config/sla.php:
return [
  'default_first_response_minutes' => 5,
  'default_resolution_minutes' => 60,
  'check_interval_seconds' => 60,
];

Create .env.example with all required variables clearly documented.

6. QUEUE CONFIGURATION
In config/queue.php, ensure Redis driver is default.
In AppServiceProvider, set queue connections with priorities:
- high: ProcessInboundMessageJob, CheckSlaBreachJob
- default: SendWhatsAppMessageJob, SendReminderJob
- low: GenerateSessionsJob, CreateReminderJobsJob, ProcessBulkImportJob

WRITE TESTS FOR:
- RoleMiddleware blocks wrong role (403) and allows correct role
- PermissionMiddleware blocks missing permission
- WebhookSignatureMiddleware rejects bad signature
- IdempotencyMiddleware: second identical wamid returns 200 without processing
- Error handler returns correct codes for each exception type
```

---

## FLUTTER PROMPT — Week 2

```
[PASTE UNIVERSAL CONTEXT BLOCK]
[Paste current progress.md]

TODAY'S TASK: Week 2 Flutter — Core components, DI, WebSocket

1. DEPENDENCY INJECTION (GetIt + injectable)
Set up injection.dart with:
- ApiClient (singleton)
- All DataSource classes (singleton)
- All Repository classes (singleton)
- All UseCase classes (factory)
- All BLoC classes (factory)

2. DIO API CLIENT
ApiClient with:
- BaseUrl from environment config
- Connect timeout: 10s, receive timeout: 30s
- JwtInterceptor: adds Authorization: Bearer {token} to every request
- RefreshInterceptor: on 401, try refresh token, retry original request
- ErrorInterceptor: converts DioException to typed AppException
- LogInterceptor: log requests/responses in debug mode only

3. WEBSOCKET SERVICE (core/websocket/websocket_service.dart)
- Connect to Reverb server with JWT auth
- Subscribe to private-user.{userId} channel
- Subscribe to presence-supervisors channel (for admin)
- Emit events via StreamController for BLoCs to listen to
- Auto-reconnect on disconnect with exponential backoff

4. REUSABLE WIDGETS (lib/core/widgets/)
Create these components (all support RTL):

StatusBadge (tag/chip with color):
- ticket statuses: new(blue), assigned(orange), pending(yellow), escalated(red), resolved(green), closed(grey)
- session statuses: upcoming(blue), done(green), postponed(yellow), cancelled(grey)
- student statuses: active(green), paused(orange), dropped(red)

TagChip (colored pill with optional remove button):
- Takes: label, color, onRemove callback (nullable)
- Rounded with background color at 20% opacity, text at 100%

AvatarCircle (user avatar):
- Shows user initials if no image URL
- Small online/offline/busy status dot in corner
- Sizes: small(32dp), medium(48dp), large(64dp)

EmptyState (for empty lists):
- Icon, title, subtitle, optional action button
- Centered in available space

ShimmerLoader (skeleton loading):
- Generic shimmer for list items
- TicketCardSkeleton (matches TicketCard dimensions)
- StudentCardSkeleton

AppSnackBar:
- success (green), error (red), warning (amber), info (teal)
- Auto-dismiss after 4s
- Show at bottom with safe area padding

5. PUSH NOTIFICATIONS (firebase_messaging)
Configure FirebaseMessaging in main.dart:
- Request permission on first launch
- Handle foreground messages (show local notification)
- Handle background tap (navigate to relevant screen via GoRouter)
- Store FCM token and send to backend on login

WRITE TESTS FOR:
- StatusBadge renders correct color for each status value
- AvatarCircle shows initials when no image
- EmptyState shows action button only when callback provided
- WebSocket service reconnects on disconnect
```

---

====================================================================
# WEEK 3 — WHATSAPP INTEGRATION
====================================================================

## BACKEND PROMPT — Week 3

```
[PASTE UNIVERSAL CONTEXT BLOCK]
[Paste current progress.md]

TODAY'S TASK: Week 3 Backend — WhatsApp integration layer

RELEVANT SPEC: See docs/architecture.md section 1.5 and docs/data_model.md tables: whatsapp_messages, whatsapp_templates, delivery_logs

1. MIGRATIONS
Create migrations for:

whatsapp_messages:
- id, wa_message_id (varchar 255, unique), ticket_id (FK nullable),
  direction (enum: inbound/outbound), from_number (varchar 20), to_number (varchar 20),
  message_type (enum: text/image/audio/video/document/template),
  content (text nullable), media_url (varchar 500 nullable),
  media_mime_type (varchar 100 nullable), template_name (varchar 255 nullable),
  delivery_status (enum: scheduled/sent/delivered/read/failed, default: scheduled),
  failure_reason (text nullable), retry_count (smallint default 0),
  idempotency_key (varchar 255 unique nullable), sent_by_id (FK users nullable),
  timestamp (timestamp), created_at
Index: wa_message_id, direction, from_number, timestamp, ticket_id

whatsapp_templates:
- id, name (varchar 255 unique), language (varchar 10), category (varchar 100),
  body_template (text), header_type (enum: none/text/image/document nullable),
  status (enum: approved/pending/rejected), timestamps

delivery_logs:
- id, message_id (FK whatsapp_messages nullable), reminder_job_id (FK reminder_jobs nullable),
  status (enum: scheduled/sent/delivered/read/failed),
  bsp_response (jsonb nullable), failure_reason (text nullable), attempted_at (timestamp)

2. MODELS
- WhatsappMessage: belongs to Ticket, belongs to User (sent_by), has many DeliveryLogs
  Cast: direction, message_type, delivery_status to backed enums
- WhatsappTemplate: has many ReminderPolicies
- DeliveryLog: belongs to WhatsappMessage

3. WHATSAPP SERVICE INTERFACE
Create app/Services/WhatsApp/WhatsAppServiceInterface.php:
```php
interface WhatsAppServiceInterface {
    public function sendText(string $to, string $message, ?string $idempotencyKey = null): array;
    public function sendTemplate(string $to, string $templateName, array $params, string $language = 'ar'): array;
    public function sendMedia(string $to, string $mediaUrl, string $type, ?string $caption = null): array;
    public function isWithinSessionWindow(string $phoneNumber): bool;
}
```

4. TWILIO IMPLEMENTATION
Create app/Services/WhatsApp/TwilioWhatsAppService.php implementing the interface:
- Use Twilio SDK (twilio/sdk)
- sendText: POST to Twilio Messages API with whatsapp: prefix
- sendTemplate: use Twilio ContentSid or template name
- isWithinSessionWindow: check last inbound message timestamp from whatsapp_messages
- All methods: log to delivery_logs, throw WhatsAppException on failure

Register in AppServiceProvider:
if (config('whatsapp.provider') === 'twilio') {
    $this->app->bind(WhatsAppServiceInterface::class, TwilioWhatsAppService::class);
}

5. WEBHOOK HANDLER
Create app/Http/Controllers/Webhook/WhatsAppWebhookController.php:
- GET verify(): respond to BSP challenge (hub.challenge)
- POST receive(): 
  a. Apply WebhookSignatureMiddleware and IdempotencyMiddleware
  b. Dispatch ProcessInboundMessageJob::dispatch($payload)
  c. Return 200 OK immediately

6. PROCESS INBOUND MESSAGE JOB
Create app/Jobs/ProcessInboundMessageJob.php (queue: high):
Steps inside handle():
a. Parse BSP payload to extract: wamid, from, to, type, content/media, timestamp
b. Resolve phone → find Guardian by whatsapp_number exact match
c. Store WhatsappMessage record (direction=inbound)
d. If media: download from BSP URL, upload to S3, set media_url
e. Find open ticket for this guardian (status not in resolved/closed)
   - If found AND ticket.owner still available: attach message to ticket
   - If not found: create new Ticket (status=new, guardian_id set, student_id if resolvable)
   - Route ticket (dispatch TicketRoutingJob or call TicketRoutingService synchronously)
f. Broadcast MessageReceived event to private-user.{ownerId} channel
Retry: max 5 times, backoff: 10s, 30s, 60s, 120s, 300s

7. SEND WHATSAPP MESSAGE JOB
Create app/Jobs/SendWhatsAppMessageJob.php (queue: default):
- Takes: WhatsappMessage $message
- Check session window via isWithinSessionWindow()
- Within window → sendText(), outside → sendTemplate() with configured template
- On success: update delivery_status=sent, log to delivery_logs
- On failure: increment retry_count, re-queue if < 3, else status=failed + log reason
Retry: max 3, backoff: 30s, 120s, 300s

8. DELIVERY STATUS CALLBACK
Add route: POST /api/webhooks/whatsapp/status
Create handler that:
- Reads wamid + status from BSP payload
- Updates whatsapp_messages.delivery_status
- Updates delivery_logs with new status + bsp_response

9. ROUTES
POST /api/webhooks/whatsapp         (no auth, WebhookSignature + Idempotency middleware)
POST /api/webhooks/whatsapp/status  (no auth, WebhookSignature middleware)
GET  /api/webhooks/whatsapp/verify  (no auth)
GET  /api/messages                  (jwt.auth, permission:tickets.view)
GET  /api/templates                 (jwt.auth, permission:reminders.manage)
POST /api/templates                 (jwt.auth, permission:reminders.manage)

WRITE TESTS FOR:
- ProcessInboundMessageJob: creates message + ticket on new contact
- ProcessInboundMessageJob: attaches message to existing open ticket
- IdempotencyMiddleware: same wamid → only 1 WhatsappMessage record
- SendWhatsAppMessageJob: uses template when outside 24h window
- SendWhatsAppMessageJob: retries up to 3 times on failure
- Delivery status webhook updates message status correctly
```

---

====================================================================
# WEEK 4 — TICKETING CORE
====================================================================

## BACKEND PROMPT — Week 4

```
[PASTE UNIVERSAL CONTEXT BLOCK]
[Paste current progress.md]

TODAY'S TASK: Week 4 Backend — Ticketing system core

RELEVANT SPEC: See docs/data_model.md tables: tickets, ticket_notes, ticket_tag, tags

1. MIGRATIONS
tickets:
- id, ticket_number (varchar 20, unique, auto-generated: TKT-YYYYMMDD-XXXX),
  status (enum: new/assigned/pending/escalated/resolved/closed, default: new),
  priority (enum: low/normal/high/urgent, default: normal),
  owner_id (FK users nullable), guardian_id (FK guardians nullable),
  student_id (FK students nullable), category (varchar 100 nullable),
  pending_reason (text nullable), resolution_reason (text nullable),
  escalation_reason (text nullable), escalated_by_id (FK users nullable),
  escalated_at (timestamp nullable), sla_policy_id (FK sla_policies nullable),
  sla_first_response_at (timestamp nullable), sla_resolved_at (timestamp nullable),
  sla_breached (bool default false), sticky_owner_id (FK users nullable),
  follow_up_at (timestamp nullable), timestamps, softDeletes
Index: status, owner_id, guardian_id, priority, created_at

tags: id, name (varchar 100 unique), color (varchar 7), timestamps
ticket_tag (pivot): ticket_id, tag_id, PRIMARY(ticket_id, tag_id)
ticket_notes: id, ticket_id (FK), author_id (FK users), content (text), is_internal (bool default true), created_at

2. MODELS
- Ticket: belongsTo User(owner), Guardian, Student, User(escalatedBy), SlaPolicy
  belongsToMany Tag, hasMany WhatsappMessage, hasMany TicketNote
  Casts: status→TicketStatus enum, priority→TicketPriority enum
  Auto-generate ticket_number in creating observer: TKT-{date}-{4-digit-seq}
  
- Tag: belongsToMany Ticket
- TicketNote: belongsTo Ticket, belongsTo User

Create enums:
- app/Enums/TicketStatus.php: New, Assigned, Pending, Escalated, Resolved, Closed
- app/Enums/TicketPriority.php: Low, Normal, High, Urgent

3. TICKET SERVICE
Create app/Services/Ticket/TicketService.php:

createFromInboundMessage(WhatsappMessage $message): Ticket
- Check sticky owner (look up tickets of this guardian for previous owner)
- Create ticket with status=new, link guardian, try to link student
- Trigger routing: TicketRoutingService::assignTicket($ticket)
- Start SLA: set sla_policy based on default or tag match
- Log to audit_logs: action=ticket.created
- Broadcast TicketCreated event

assign(Ticket $ticket, User $supervisor, User $assignedBy): void
- Update owner_id, status=assigned
- Validate: supervisor must have role supervisor/senior_supervisor
- Validate: supervisor.max_open_tickets not exceeded
- Log audit: ticket.assigned
- Broadcast TicketAssigned to both old and new owner

reply(Ticket $ticket, User $sender, string $content, ?UploadedFile $media = null): WhatsappMessage
- Create WhatsappMessage (direction=outbound)
- If sla_first_response_at is null: set it to now()
- Dispatch SendWhatsAppMessageJob
- Log audit: message.sent

markPending(Ticket $ticket, User $user, string $reason): void
- Set status=pending, pending_reason=$reason
- Log audit: ticket.pending

resolve(Ticket $ticket, User $user, string $reason): void
- Set status=resolved, resolution_reason, sla_resolved_at=now()
- Log audit: ticket.resolved

close(Ticket $ticket, User $user): void
- Set status=closed
- Log audit: ticket.closed

addTag(Ticket $ticket, int $tagId): void
addNote(Ticket $ticket, User $author, string $content, bool $internal = true): TicketNote
setFollowUp(Ticket $ticket, User $user, Carbon $at): void

4. TAG MANAGEMENT SERVICE
Create app/Services/Ticket/TagService.php:
- list(), create(name, color), update(id, name, color), delete(id)

5. CONTROLLERS
TicketController (all routes under jwt.auth):
- index: paginated list, filters: status, owner_id, priority, tags, search, sort
- show: ticket with messages (paginated), notes, tags
- assign: POST /{id}/assign {supervisor_id}
- reply: POST /{id}/reply {content, media?}
- status: POST /{id}/status {status, reason}
- escalate: POST /{id}/escalate {reason} → use EscalationService (week 5)
- addNote: POST /{id}/notes {content, is_internal}
- setFollowUp: POST /{id}/follow-up {follow_up_at}

TagController: CRUD for /api/tags

6. ROUTES
GET    /api/tickets                 (permission:tickets.view)
GET    /api/tickets/{id}            (permission:tickets.view)
POST   /api/tickets/{id}/assign     (permission:tickets.assign)
POST   /api/tickets/{id}/reply      (permission:tickets.reply)
POST   /api/tickets/{id}/status     (permission:tickets.resolve)
POST   /api/tickets/{id}/escalate   (permission:tickets.escalate)
POST   /api/tickets/{id}/notes      (permission:tickets.view)
POST   /api/tickets/{id}/follow-up  (permission:tickets.view)
GET    /api/tickets/{id}/messages   (permission:tickets.view)
GET    /api/tickets/{id}/timeline   (permission:tickets.view)
GET    /api/tags                    (jwt.auth)
POST   /api/tags                    (permission:tickets.view)

WRITE TESTS FOR:
- Create ticket from message sets correct status and guardian link
- Assign validates max_open_tickets limit
- Reply sets sla_first_response_at on first response only
- Status transitions: pending→assigned ok, closed→assigned rejected
- Each action creates audit_log entry
- Tag filter returns only tickets with that tag
```

---

## FLUTTER PROMPT — Week 4

```
[PASTE UNIVERSAL CONTEXT BLOCK]
[Paste current progress.md]

TODAY'S TASK: Week 4 Flutter — Supervisor Inbox + Ticket Detail

RELEVANT SPEC: See docs/flutter_app.md sections 4.2 (Inbox screen, Ticket Detail screen) and 4.3 (TicketCard, SlaTimerPill, MessageBubble components)

1. TICKET FEATURE FOLDER STRUCTURE
lib/features/tickets/
├── data/
│   ├── ticket_repository.dart
│   ├── ticket_remote_datasource.dart  (Dio calls to /api/tickets/*)
│   ├── ticket_local_datasource.dart   (Hive cache)
│   └── models/ (TicketModel, MessageModel, NoteModel — freezed)
├── domain/
│   ├── entities/ (TicketEntity, MessageEntity — freezed)
│   └── usecases/ (GetTicketsUseCase, GetTicketDetailUseCase, ReplyToTicketUseCase)
└── presentation/
    ├── bloc/
    │   ├── ticket_list_bloc.dart   (states: Loading, Loaded, Error, Empty)
    │   ├── ticket_detail_bloc.dart (states: Loading, Loaded, Sending, Error)
    │   └── chat_bloc.dart
    ├── screens/
    │   ├── inbox_screen.dart
    │   └── ticket_detail_screen.dart
    └── widgets/
        ├── ticket_card.dart
        ├── sla_timer_pill.dart
        ├── message_bubble.dart
        └── ticket_action_sheet.dart

2. TICKET CARD WIDGET
Design the TicketCard with:
- Left border strip: color based on priority (low=grey, normal=blue, high=orange, urgent=red)
- Row 1: ticket number (small, grey) + StatusBadge(status) + SlaTimerPill
- Row 2: Guardian name (bold) + Student name (smaller, grey)  
- Row 3: Last message preview (1 line, ellipsis) + time ago (right)
- Tags row: horizontal list of TagChip
- Tap: navigate to TicketDetailScreen with hero animation on card

3. SLA TIMER PILL WIDGET
- Shows countdown: "4:32" (mm:ss format)
- Colors: green (>50% time left), amber (25-50%), red (<25%), dark red pulsing (<1min)
- Updates every second using Timer.periodic in StatefulWidget
- If sla_breached=true: show "تجاوز" with red background (no countdown)

4. INBOX SCREEN
- AppBar with "صندوق الوارد" title + filter icon + search icon
- Status filter tabs: كل (All) | جديد | مُسند | معلق | مُصعَّد
- List of TicketCard via BlocBuilder
- Pull-to-refresh (RefreshIndicator)
- Infinite scroll pagination (load more on scroll end)
- ShimmerLoader when loading first page
- EmptyState if no tickets in current filter
- FAB (for supervisor to create manual ticket — future)
- WebSocket: listen to TicketCreated + TicketAssigned events → reload list

5. TICKET DETAIL SCREEN
- AppBar: ticket number + status badge + 3-dot menu
- 3-dot menu: Assign, Escalate, Set Status, Add Note, Set Follow-up
- Tab bar: المحادثة (Chat) | الملاحظات (Notes) | التفاصيل (Details)
- Chat tab: WhatsApp-style message list
  - Inbound bubbles: left, grey background, guardian name above first message
  - Outbound bubbles: right, teal background, "أنت" label
  - Timestamps below each bubble
  - Delivery status icons: ✓ sent, ✓✓ delivered, 🔵✓✓ read
  - Date separators between days
  - Media messages: image thumbnail / audio player / PDF icon with filename
- Input bar (bottom): text field + attach icon + send icon
  - Attach opens bottom sheet: Camera | Gallery | Document
- Notes tab: list of internal notes with author + timestamp (yellow background)
- Details tab: guardian info, student info, tags, SLA info, created date

6. REPLY FUNCTIONALITY
- User types message and taps send
- ChatBloc dispatches SendReplyEvent
- Show optimistic message (greyed out) immediately
- On success: update message with server response
- On failure: show retry button on message bubble

WRITE TESTS FOR:
- TicketListBloc: loading state → loaded state with ticket list
- TicketListBloc: filter by status changes ticket list
- TicketDetailBloc: send reply dispatches correct API call
- SlaTimerPill: shows correct color class based on percentage remaining
- TicketCard: renders all fields correctly
```

---

====================================================================
# WEEK 5 — TICKETING ADVANCED (Escalation, SLA, Routing)
====================================================================

## BACKEND PROMPT — Week 5

```
[PASTE UNIVERSAL CONTEXT BLOCK]
[Paste current progress.md]

TODAY'S TASK: Week 5 Backend — Routing, Escalation, SLA, Overflow

RELEVANT SPEC: docs/architecture.md sections H (Routing), I (Escalation), J (SLA)

1. ROUTING ENGINE (Strategy Pattern)
Create app/Services/Routing/RoutingStrategyInterface.php:
interface RoutingStrategyInterface {
    public function selectSupervisor(Ticket $ticket, Collection $eligibleSupervisors): ?User;
}

Create implementations:
- RoundRobinStrategy: find supervisor with oldest last_assigned_at (or least tickets today)
- LeastLoadStrategy: find supervisor with minimum open tickets count

Create app/Services/Routing/RoutingEngineService.php:
- selectStrategy(RoutingRule $rule): RoutingStrategyInterface
- assignTicket(Ticket $ticket): void
  a. Check sticky owner: if ticket.guardian had previous ticket with resolved owner who is available → assign to them
  b. Load active routing_rules ordered by priority
  c. For each rule: check conditions match ticket (tags, time_of_day, category)
  d. Filter supervisors: role=supervisor, availability=available, open_tickets < max_open_tickets
  e. Apply rule's algorithm strategy to select supervisor
  f. If no supervisor found AND overflow: assign to admin queue (owner_id=null, status=new with admin notification)
  g. Call TicketService::assign()

2. ROUTING RULES CRUD
migrations/create_routing_rules_table:
- id, name, algorithm (enum: round_robin/least_load/tag_based/time_based),
  priority (int), conditions (jsonb), target_user_ids (jsonb), is_active (bool), timestamps

RoutingRuleController (admin only, permission:routing.manage):
GET    /api/admin/routing-rules
POST   /api/admin/routing-rules
PUT    /api/admin/routing-rules/{id}
DELETE /api/admin/routing-rules/{id}
PUT    /api/admin/routing-rules/reorder  {rules: [{id, priority}]}

3. ESCALATION SERVICE
Create app/Services/Ticket/EscalationService.php:
escalate(Ticket $ticket, User $escalatedBy, string $reason): void
- Validate: ticket is not already escalated or closed
- Update: status=escalated, priority=urgent, escalation_reason, escalated_by_id, escalated_at
- Notify admin via broadcast: TicketEscalated event to private-admin channel
- Log audit: ticket.escalated

adminTakeOver(Ticket $ticket, User $admin): void
- Assign ticket to admin user
- Log audit: ticket.taken_over_by_admin

addAdminInstructionNote(Ticket $ticket, User $admin, string $note): TicketNote
- Create internal note (is_internal=true)

4. SLA SERVICE + CHECKER JOB
migrations/create_sla_policies_table:
- id, name, tag_match (varchar 100 nullable), first_response_minutes (int),
  resolution_minutes (int), warning_threshold_pct (int default 80),
  auto_escalate (bool default false), timestamps

Create app/Services/Ticket/SlaService.php:
assignPolicy(Ticket $ticket): void
- Find matching sla_policy where tag_match IN ticket.tags (or default policy)
- Set ticket.sla_policy_id

checkBreach(Ticket $ticket): void
- Calculate elapsed minutes since created_at
- Check first response: if no sla_first_response_at AND elapsed > first_response_minutes → mark breached
- Check warning: if elapsed > (first_response_min * warning_pct/100) → push warning notification
- If auto_escalate and breached → call EscalationService::escalate()

Create app/Jobs/CheckSlaBreachJob.php (queue: high):
- Query all non-breached tickets with status in (new, assigned, pending)
- For each: call SlaService::checkBreach()
- Must complete in < 60 seconds total (batch process efficiently)

Add to scheduler: $schedule->job(new CheckSlaBreachJob)->everyMinute()

5. OVERFLOW RULES
In TicketService + RoutingEngineService:
- If selected supervisor has open_tickets >= max_open_tickets → skip them
- If ALL supervisors are full → create ticket with owner_id=null, broadcast to admin channel: "Overflow ticket in queue"
- Admin can see unassigned tickets in their queue

6. STICKY OWNER
In RoutingEngineService::assignTicket():
- Before running rules: check if guardian has any recently resolved tickets (< 30 days)
- If yes AND that supervisor is currently available → assign to them (sticky owner)
- Log note: "Assigned to previous supervisor (sticky)"

WRITE TESTS FOR:
- RoundRobinStrategy distributes tickets evenly
- LeastLoadStrategy picks supervisor with fewest open tickets
- Sticky owner correctly identifies and assigns previous supervisor
- Overflow when all supervisors full: ticket unassigned, admin notified
- SLA breach detection fires at correct elapsed time
- Auto-escalate triggered when configured
- Routing rule conditions: tag match works, time range works
```

---

====================================================================
# WEEK 6 — STUDENTS CRM
====================================================================

## BACKEND PROMPT — Week 6

```
[PASTE UNIVERSAL CONTEXT BLOCK]
[Paste current progress.md]

TODAY'S TASK: Week 6 Backend — Students & Guardians CRM

RELEVANT SPEC: docs/data_model.md tables: students, guardians, guardian_student, student_notes

1. MIGRATIONS
students: id, full_name (varchar 255), status (enum: active/paused/dropped, default:active),
  notes (text nullable), timestamps, softDeletes

guardians: id, full_name (varchar 255), whatsapp_number (varchar 20, UNIQUE),
  backup_number (varchar 20 nullable), email (varchar 255 nullable), timestamps, softDeletes

guardian_student (pivot): id, guardian_id (FK), student_id (FK), relationship (varchar 50),
  is_primary (bool default true), UNIQUE(guardian_id, student_id)

student_notes: id, student_id (FK), author_id (FK users), content (text), created_at

2. MODELS
Student: belongsToMany Guardian (via guardian_student), hasMany StudentNote, hasMany Ticket,
  hasMany Session (via schedule). Status cast to StudentStatus enum.
Guardian: belongsToMany Student. whatsapp_number always stored in E.164 format.
StudentNote: belongsTo Student, belongsTo User.

3. STUDENT SERVICE
Create app/Services/Student/StudentService.php:
- list(array $filters): phone filter, status filter, search by name, paginate
- create(array $data): validate unique guardian phone before creating
- update(Student $student, array $data): 
- changeStatus(Student $student, string $status, User $changedBy): log audit
- delete(Student $student): softDelete, log audit
- getTimeline(Student $student): merge and sort: last 20 whatsapp messages + student notes + last 10 sessions

4. GUARDIAN SERVICE
Create app/Services/Student/GuardianService.php:
- normalizePhone(string $phone): covert to E.164 (+966XXXXXXXXX format)
- validateWhatsapp(string $phone): check format validity (not BSP API check yet)
- deduplicate check: before create/update, verify no other guardian has same whatsapp_number
- create, update, linkToStudent(guardian, student, relationship, isPrimary), unlinkFromStudent
- resolveFromPhone(string $phone): find Guardian by whatsapp_number → for ProcessInboundMessageJob

5. CONTROLLERS
StudentController (permission:students.view for GET, students.create/edit/delete for mutations):
GET    /api/students                (paginated, search, status filter)
GET    /api/students/{id}           (with guardians, recent messages)
POST   /api/students                
PUT    /api/students/{id}          
DELETE /api/students/{id}          
GET    /api/students/{id}/timeline  (last N messages + notes + sessions combined)
POST   /api/students/{id}/notes    

GuardianController:
GET    /api/guardians
GET    /api/guardians/{id}
POST   /api/guardians
PUT    /api/guardians/{id}
POST   /api/guardians/{id}/students    {student_id, relationship, is_primary}
DELETE /api/guardians/{id}/students/{studentId}

6. PHONE NORMALIZATION
In GuardianService::normalizePhone():
- Strip all non-digit characters
- Handle Saudi numbers: if starts with 05 → replace with +9665
- Handle Egyptian numbers: if starts with 01 → replace with +201
- If already has + → format correctly
- Return E.164 format or throw PhoneFormatException

WRITE TESTS FOR:
- Create student: happy path creates student + audit log
- Create guardian: duplicate whatsapp_number returns 422
- Phone normalization: 0501234567 → +966501234567
- Phone normalization: 01234567890 (Egypt) → +201234567890
- resolveFromPhone: finds guardian by normalized number
- Timeline: returns merged sorted list of messages + notes + sessions
- Link guardian to student: creates pivot correctly
```

## FLUTTER PROMPT — Week 6

```
[PASTE UNIVERSAL CONTEXT BLOCK]
[Paste current progress.md]

TODAY'S TASK: Week 6 Flutter — Students section (Admin dashboard)

RELEVANT SPEC: docs/flutter_app.md sections: Students screens, Student Detail

1. STUDENT FEATURE FOLDER
lib/features/students/ (same structure as tickets feature)

2. STUDENT LIST SCREEN (Admin)
- SearchBar at top with debounce (300ms)
- Filter chips row: All | Active | Paused | Dropped
- Student list using StudentCard:
  - Avatar (initials) + name + status badge
  - Primary guardian phone number
  - Number of linked guardians
  - Tap → StudentDetailScreen

3. STUDENT DETAIL SCREEN
- Header: Avatar (large), name, status badge, action buttons (Edit, Change Status)
- Guardians card: list of linked guardians with phone numbers + relationship labels
  - "+" button to add guardian or link existing
- Tabs: Timeline | Messages | Notes
- Timeline tab: chronological feed
  - WhatsApp messages (chat bubble preview style, tap to open full message)
  - Session records (card with date, teacher, status)
  - Internal notes (yellow background card)
- Notes tab: list of notes with "Add Note" FAB

4. ADD/EDIT STUDENT SCREEN (bottom sheet or full screen)
- Full name field (Arabic label: الاسم الكامل)
- Status dropdown: Active/Paused/Dropped
- Notes field (multi-line)
- Primary guardian section: search existing guardian by phone OR create new
  - Phone field with auto-formatting (show +966 prefix)
  - Guardian name field
  - Relationship dropdown

5. BULK IMPORT SCREEN
- Upload button → FilePicker (xlsx files only)
- After selection: show preview table with first 5 rows
- Validation summary: Total rows | Valid | Invalid | Duplicates
- Error list: row number + field + error message
- "Import" button (disabled if too many errors)
- Progress indicator while importing
- Success summary when done

WRITE TESTS FOR:
- StudentListBloc: filter by status returns filtered results
- StudentDetailBloc: timeline merges messages+notes+sessions correctly
- Phone field auto-formats to E.164 display
- BulkImport: shows validation errors before allowing import
```
