# 7. Testing, DevOps, NFRs, Coding Standards & Extensibility

## 7.1 Testing Strategy

### Unit Tests (PHPUnit + Flutter test)

**Backend targets (≥80% coverage on services):**

| Service | Key Test Cases |
|---------|---------------|
| `TicketService` | Create from message, status transitions, invalid transition rejection |
| `TicketRoutingService` | Round robin distributes evenly, least load picks correct user, sticky owner returns same |
| `SlaService` | Timer starts on creation, breach detected correctly, warning at threshold |
| `SessionGeneratorService` | Generates correct dates for day_of_week, skips existing (idempotent), detects conflicts |
| `ConflictCheckerService` | Overlapping times detected, adjacent times allowed, same teacher flagged |
| `ReminderSchedulerService` | Creates jobs for correct recipients, idempotency key unique, cancelled session skipped |
| `WebhookProcessorService` | Valid payload processing, duplicate wamid rejected, unknown contact handled |
| `BulkImportService` | Valid rows imported, invalid phones rejected, duplicates detected |
| `WhatsAppService` | Template params resolved, session window check, retry count respected |

**Flutter unit tests:**
- BLoC state transitions for every feature (ticket, student, schedule)
- Repository mock tests (Mockito)
- Model serialization/deserialization (freezed)
- Validator functions (phone, email, date)

### Integration Tests (Feature Tests)

| Test Case | What It Validates |
|-----------|-------------------|
| **Webhook Idempotency** | POST same wamid twice → only 1 message + 1 ticket created |
| **Full Ticket Lifecycle** | Inbound → ticket created → assigned → replied → resolved → closed |
| **SLA Breach** | Create ticket → wait past SLA → CheckSlaBreachJob → ticket.sla_breached = true |
| **Reminder Dedupe** | Run CreateReminderJobsJob twice for same day → same # of reminder_jobs |
| **Session Generation Dedupe** | Run GenerateSessionsJob twice → same # of sessions |
| **Escalation Flow** | Escalate ticket → status=escalated, priority=high, admin notified |
| **Bulk Import** | Upload valid Excel → students + guardians created, phone normalized |
| **Auth + RBAC** | Supervisor cannot access admin endpoints, admin can access all |
| **Routing Overflow** | Fill supervisor to max_open_tickets → next ticket routes to admin |

### E2E Tests

- Using Pest (Laravel) for backend flow tests
- Using `integration_test` package for Flutter
- Key E2E: Login → See inbox → Open ticket → Reply → Verify delivery status update

### Test Commands
```bash
# Backend
php artisan test --filter=Unit
php artisan test --filter=Feature
php artisan test --parallel

# Flutter
flutter test
flutter test --coverage
flutter test integration_test/
```

---

## 7.2 DevOps Plan

### Environments

| Environment | Purpose | Infrastructure |
|-------------|---------|---------------|
| `local` | Development | Docker Compose (Laravel + PG + Redis + Reverb) |
| `staging` | QA + Demo | Single VPS or Cloud Run, staging BSP webhook |
| `production` | Live | Cloud VPS / DigitalOcean / AWS, auto-scaling |

### Docker Setup
```yaml
# docker-compose.yml
services:
  app:        # Laravel PHP-FPM
  nginx:      # Reverse proxy
  postgres:   # PostgreSQL 15
  redis:      # Redis 7
  queue:      # Laravel queue worker (php artisan queue:work)
  scheduler:  # Laravel scheduler (php artisan schedule:work)
  reverb:     # Laravel Reverb WebSocket server
```

### CI/CD (GitHub Actions)

```yaml
# .github/workflows/ci.yml
on: [push, pull_request]
jobs:
  backend:
    - PHP lint (phpcs + phpstan)
    - PHPUnit tests
    - Coverage report upload
  flutter:
    - Dart analyze
    - Flutter test
    - Build APK (on main branch only)
  deploy-staging:
    - on: push to main
    - SSH deploy to staging server
    - Run migrations
    - Restart queue workers
  deploy-production:
    - on: tag v*
    - Manual approval gate
    - Blue-green deploy
    - Run migrations
    - Health check verification
```

### Secrets Management
- `.env` files NOT committed (in .gitignore)
- Staging/Production secrets in GitHub Secrets or cloud KMS
- WhatsApp BSP tokens, JWT secret, DB credentials encrypted
- Rotate secrets every 90 days

### Backups & Migrations
- **PostgreSQL**: Daily automated backup (pg_dump) → S3
- **Retention**: 30 daily + 12 weekly + 6 monthly
- **Migrations**: `php artisan migrate` in CI/CD pipeline, rollback on failure
- **Media files**: S3 with versioning enabled

### Monitoring & Observability

| Layer | Tool | Purpose |
|-------|------|---------|
| APM | Laravel Telescope (dev) | Query, job, request inspection |
| Logs | Laravel Log → Papertrail / CloudWatch | Centralized logging |
| Metrics | Prometheus + Grafana | Queue depth, response times, error rates |
| Uptime | UptimeRobot / Better Uptime | API + WebSocket health checks |
| Errors | Sentry (Laravel + Flutter) | Exception tracking with context |
| Alerts | Grafana alerts → Slack/WhatsApp | SLA breaches, queue backlog, errors |

---

## 7.3 Non-Functional Requirements

| Category | Target |
|----------|--------|
| **API Response Time** | p95 < 200ms for list endpoints, p99 < 500ms |
| **Webhook Processing** | < 2s from receipt to ticket creation |
| **Concurrent Users** | Support 50+ simultaneous mobile app users |
| **Message Volume** | Handle 10,000+ WhatsApp messages/day |
| **Uptime** | 99.5% (staging), 99.9% (production) |
| **DB Queries** | No N+1, all lists use eager loading |
| **Queue Latency** | high queue: < 5s, default: < 30s, low: < 5min |
| **Offline Tolerance** | App usable in read-only mode for 1h offline |
| **App Launch** | Cold start < 3s, hot start < 1s |
| **Data Retention** | Messages: 2 years, Audit logs: 5 years |

---

## 7.4 Coding Standards

### Backend (Laravel/PHP)

| Standard | Details |
|----------|---------|
| PHP Version | 8.2+ with strict types |
| Style | PSR-12 via `phpcs` |
| Static Analysis | PHPStan level 6+ |
| Enums | PHP 8.1 backed enums for all statuses |
| DTOs | Data Transfer Objects for service layer inputs |
| Form Requests | Validation on every endpoint |
| API Resources | Laravel API Resources for response formatting |
| Repository Pattern | Optional, use Eloquent directly in services for MVP |
| Naming | Services: `{Entity}Service`, Jobs: `{Verb}{Entity}Job` |
| Documentation | PHPDoc on all public service methods |

### Flutter/Dart

| Standard | Details |
|----------|---------|
| Dart Version | 3.x with null safety |
| Linting | `flutter_lints` + custom analysis_options.yaml |
| Architecture | Clean Architecture (data/domain/presentation per feature) |
| State | flutter_bloc with sealed events + states |
| Models | freezed + json_serializable for immutability |
| DI | GetIt + injectable for compile-time safety |
| Naming | Screens: `{Feature}Screen`, BLoCs: `{Feature}Bloc` |
| Tests | Minimum 1 test per BLoC, 1 per repository |

### Shared Patterns
- **Feature flags**: Config table `system_settings` with key-value, cached in Redis
- **Error handling**: Custom exception classes, global handler, user-friendly messages
- **Logging**: Structured JSON logs with correlation ID per request
- **Git**: Conventional commits, branch naming: `feature/`, `fix/`, `chore/`
- **PR process**: Required review, CI must pass, squash merge

---

## 7.5 Future Extensibility Points

### Adding New Reminder Types
1. Add new row to `reminder_policies` with template reference
2. `CreateReminderJobsJob` already queries all active policies → auto-included
3. No code change needed — fully data-driven

### Adding New Ticket Categories
1. Add new `tags` record
2. Optionally add matching `sla_policy` with `tag_match`
3. Add matching `routing_rule` with conditions
4. UI auto-discovers tags via API

### Adding New Routing Algorithms
1. Create new class implementing `RoutingStrategyInterface`
2. Register in `RoutingEngineService` strategy map
3. Add new `algorithm` enum value in `routing_rules`
4. **Strategy Pattern** ensures zero changes to existing code

### Adding New Roles
1. Create role via Spatie: `Role::create(['name' => 'accountant'])`
2. Assign permissions to role
3. Add dashboard route guard in Flutter GoRouter
4. Create new dashboard screen

### Adding New Report Types
1. Create new method in `AnalyticsService`
2. Add API endpoint
3. Add Flutter screen with `fl_chart` visualization

### Future Module Integration Points
| Module | Integration Strategy |
|--------|---------------------|
| **Payments** | Add `payments` table, link to `students`, new ticket category |
| **Attendance** | Extend `sessions` with attendance tracking fields |
| **Parent Portal** | New Flutter web/mobile app consuming same API |
| **AI Auto-Reply** | New `AutoReplyService` subscribing to `MessageReceived` event |
| **Multi-Academy** | Add `academy_id` tenant column, scope all queries |
| **WhatsApp Chatbot** | New `ChatbotService` in WhatsApp module, rule-based or AI |

### Architectural Enablers
- **Event-driven**: All major actions emit events → subscribe new listeners without touching existing code
- **Interface contracts**: WhatsApp BSP, routing strategies, notification channels — all behind interfaces
- **Config-driven**: SLA, routing, reminders all stored in DB, changeable without deploy
- **Queue-based**: New job types can be added and routed to appropriate queue workers
- **Feature flags**: Toggle new features per-environment without deploy
