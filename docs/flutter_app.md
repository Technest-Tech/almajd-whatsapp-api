# 4. Flutter Mobile App Specification

## 4.1 Navigation Map

```
Login Screen
    │
    ▼ (role-based routing)
    ├── SUPERVISOR DASHBOARD ──────────────────────────────
    │   ├── Inbox (ticket list with SLA countdown)
    │   │   └── Ticket Detail
    │   │       ├── Chat View (WhatsApp-style messaging)
    │   │       ├── Ticket Actions (assign, status, escalate)
    │   │       └── Internal Notes
    │   ├── Search & Filters
    │   ├── Notifications
    │   └── Profile / Settings
    │
    ├── SENIOR SUPERVISOR DASHBOARD ───────────────────────
    │   ├── Everything from Supervisor +
    │   ├── Team Overview (supervisors + their tickets)
    │   ├── Escalation Queue
    │   └── Basic Analytics
    │
    └── ADMIN DASHBOARD ───────────────────────────────────
        ├── Overview (KPI cards, charts)
        ├── Tickets (all tickets, bulk actions)
        ├── Students
        │   ├── Student List + Search
        │   ├── Student Detail (timeline)
        │   ├── Add/Edit Student
        │   ├── Guardians Management
        │   └── Bulk Import
        ├── Teachers
        │   ├── Teacher List
        │   └── Add/Edit Teacher
        ├── Timetables
        │   ├── Schedules List / Calendar View
        │   ├── Create/Edit Schedule
        │   ├── Sessions List
        │   ├── Session Detail (cancel/reschedule)
        │   └── Generate Sessions
        ├── Reminders
        │   ├── Reminder Policies
        │   ├── Delivery Log
        │   └── Failed / Retry Queue
        ├── Users & Roles
        │   ├── User Management
        │   ├── Role / Permission Editor
        │   └── Routing Rules
        ├── Settings
        │   ├── SLA Policies
        │   ├── WhatsApp Templates
        │   └── Class Entities
        ├── Analytics
        │   ├── Ticket Analytics
        │   ├── SLA Compliance
        │   ├── Supervisor Performance
        │   └── Reminder Reports
        └── Audit Log
```

## 4.2 Screen Specifications

### Login Screen
- Email + password fields with validation
- Biometric auth option (FaceID / Fingerprint)
- "Remember me" toggle
- Password visibility toggle
- Loading state with shimmer animation
- Error handling with snackbar

### Supervisor Inbox
- **Card-based list** with pull-to-refresh
- Each `TicketCard` shows: ticket #, priority chip, status badge, guardian name, student name, last message preview, time ago, unread count, **SLA timer pill** (countdown, color-coded green→yellow→red)
- **Floating filters**: status tabs (New | Assigned | Pending | Escalated | All)
- **Sort by**: newest, oldest, priority, SLA urgency
- **Quick actions**: swipe-right to assign self, swipe-left to mark pending
- **FAB**: manually create ticket
- **Empty state**: illustration + "No tickets" message

### Ticket Detail / Chat View
- **Header**: ticket #, status badge, priority, SLA timer, guardian phone
- **Chat area**: WhatsApp-style bubbles with:
  - Inbound messages (left, light background)
  - Outbound messages (right, tinted brand color)
  - System messages (center, grey — "Ticket assigned to Ahmad")
  - Media previews: images, audio player, PDF thumbnails
  - Timestamps, delivery status icons (✓ ✓✓)
- **Input bar**: text field + attachment button (camera, gallery, document) + send
- **Bottom sheet actions**: Assign, Escalate, Set Status, Add Note, Set Follow-up
- **Internal notes tab**: visible only to staff, indicated by yellow highlight

### Admin Overview
- **KPI row**: Cards with icon + value + trend arrow (tickets today, avg response, SLA %, active sessions)
- **Charts**: Line chart (tickets/day last 7d), bar chart (by supervisor), pie (by tag)
- **Quick links**: "Escalated tickets (3)", "Failed reminders (2)", "SLA breaches today (1)"

### Student Detail
- **Profile header**: name, status chip, guardians list
- **Tabs**: Timeline | Messages | Sessions | Notes
- **Timeline**: chronological feed mixing messages, notes, session history
- **Actions**: Edit, Change Status, Add Note, View Guardian

### Schedule / Timetable View
- **Toggle**: List view ↔ Calendar view (weekly calendar)
- **Calendar**: color-coded by teacher, tap to view/edit session
- **Create flow**: stepped form (title → student/group → teacher → day/time → online/offline)

## 4.3 Component Library

| Component | Description | Used In |
|-----------|-------------|---------|
| `TicketCard` | Card with priority strip, SLA pill, last message preview | Inbox, Search |
| `SlaTimerPill` | Countdown badge, color transitions by urgency | TicketCard, TicketDetail |
| `StatusBadge` | Colored chip for ticket/session/student status | All lists |
| `PriorityChip` | Icon + label (Low/Normal/High/Urgent) | Tickets |
| `MessageBubble` | Chat bubble with direction, timestamp, status | Chat view |
| `MediaPreview` | Image thumbnail, audio waveform, PDF icon | Chat view |
| `TagChip` | Colored tag pill with optional remove button | Tickets, filters |
| `AvatarCircle` | User/student initials avatar with status dot | All screens |
| `KpiCard` | Icon + value + label + trend indicator | Admin dashboard |
| `EmptyState` | Illustration + message + optional action button | All lists |
| `SearchBar` | Animated search with filter chips below | Global search |
| `ShimmerLoader` | Skeleton loading animation for all list screens | Loading states |
| `ConfirmationSheet` | Bottom sheet with action confirmation | Destructive actions |
| `SteppedForm` | Multi-step form with progress indicator | Create schedule, import |

## 4.4 State Management & Architecture

### Pattern: flutter_bloc + Clean Architecture

```
lib/
├── core/
│   ├── api/                    # Dio client, interceptors, response models
│   │   ├── api_client.dart
│   │   ├── api_interceptors.dart
│   │   └── api_response.dart
│   ├── auth/                   # Auth BLoC, token storage
│   ├── di/                     # GetIt dependency injection
│   ├── router/                 # GoRouter with role-based guards
│   ├── theme/                  # Dark/light theme, colors, typography
│   ├── l10n/                   # Arabic + English localizations
│   ├── utils/                  # Formatters, validators, helpers
│   └── widgets/                # Shared component library (above)
│
├── features/
│   ├── auth/
│   │   ├── data/               # AuthRepository, AuthRemoteDataSource
│   │   ├── domain/             # LoginUseCase, User entity
│   │   └── presentation/       # LoginScreen, AuthBloc
│   │
│   ├── tickets/
│   │   ├── data/               # TicketRepository, TicketRemoteDS, TicketLocalDS
│   │   ├── domain/             # Ticket entity, use cases
│   │   └── presentation/
│   │       ├── bloc/           # TicketListBloc, TicketDetailBloc, ChatBloc
│   │       ├── screens/        # InboxScreen, TicketDetailScreen
│   │       └── widgets/        # TicketCard, MessageBubble, etc.
│   │
│   ├── students/               # Same structure
│   ├── teachers/               # Same structure
│   ├── timetables/             # Same structure
│   ├── reminders/              # Same structure
│   ├── analytics/              # Same structure
│   ├── users_roles/            # Same structure
│   └── settings/               # SLA, templates, routing rules
│
├── main.dart
└── app.dart
```

### Key Packages
| Package | Purpose |
|---------|---------|
| `flutter_bloc` | State management |
| `get_it` + `injectable` | Dependency injection |
| `go_router` | Declarative routing with guards |
| `dio` | HTTP client with interceptors |
| `web_socket_channel` | WebSocket for realtime |
| `hive` / `drift` | Local DB for offline cache |
| `firebase_messaging` | Push notifications |
| `intl` | Date/time formatting, Arabic |
| `flutter_local_notifications` | Local notification display |
| `freezed` + `json_serializable` | Immutable models + JSON |
| `cached_network_image` | Image caching |
| `fl_chart` | Charts for analytics |
| `file_picker` / `image_picker` | Media attachments |
| `excel` | Bulk import Excel parsing preview |

## 4.5 UI/UX Guidelines

### Design System
- **Framework**: Material 3 (Material You) with custom color scheme
- **Primary**: Deep Teal `#00897B` → modern, professional
- **Accent**: Amber `#FFA000` → alerts, SLA warnings
- **Error**: Coral `#FF5252`
- **Typography**: Google Fonts `Cairo` (Arabic-optimized) + `Inter` (Latin fallback)
- **Radius**: 12dp cards, 20dp bottom sheets, 24dp chips
- **Elevation**: Subtle shadows (0–4dp), no harsh drop shadows
- **Spacing**: 8dp grid system

### Dark Mode
- Full dark mode using `ThemeData.dark()` extension
- OLED-optimized true black `#000000` background
- Adjusted contrast ratios for readability
- Toggle in Settings or follow system

### RTL / Arabic First
- Default locale: `ar`
- `Directionality.rtl` as default
- All layouts use `start/end` instead of `left/right`
- Proper Arabic date/time formatting via `intl`

### Animations
- **Page transitions**: Shared element hero animations for ticket cards
- **List items**: Staggered fade-in on load
- **SLA pill**: Pulsing animation when < 1 min remaining
- **Pull-to-refresh**: Custom branded animation
- **Bottom sheets**: Spring curve slide-up
- **Swipe actions**: Smooth reveal with haptic feedback

### Accessibility
- Minimum tap targets: 48×48dp
- Font scaling: support system font size (up to 2x)
- Semantic labels on all interactive elements
- Color contrast: WCAG AA minimum (4.5:1)
- Screen reader support via `Semantics` widgets

### Offline Patterns
- Cache last inbox state in Hive
- Queue outgoing actions (replies, status changes) when offline
- Sync queue on reconnect with conflict resolution
- Show "Offline" banner with last sync timestamp
- Graceful degradation: read-only mode when offline
