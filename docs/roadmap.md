# 6. Implementation Roadmap

## 6.1 MVP Plan (12 Weeks)

### Phase 1: Foundation (Weeks 1–2)

**Week 1 — Project Setup & Auth**
| Task | Details |
|------|---------|
| Laravel project init | Laravel 11, PostgreSQL, Redis, Docker Compose |
| Auth system | JWT (tymon/jwt-auth), login/refresh/logout, device_sessions |
| RBAC scaffold | Spatie laravel-permission, seed 3 roles + default permissions |
| Flutter project init | Clean architecture folders, GoRouter, flutter_bloc, DI (GetIt) |
| Flutter auth | Login screen, token storage (flutter_secure_storage), auth BLoC |
| CI/CD pipeline | GitHub Actions: lint + test on PR |

**Week 2 — Core Infrastructure**
| Task | Details |
|------|---------|
| Middleware | Role, Permission, Idempotency, WebhookSignature |
| Base API | Standardized response envelope, error handling, pagination |
| WebSocket setup | Laravel Reverb or Pusher config, channel auth |
| Flutter networking | Dio client, interceptors, WebSocket connection |
| Theme & design system | Material 3 theme, Cairo font, dark mode, RTL |
| Component library (v1) | StatusBadge, TagChip, AvatarCircle, EmptyState, ShimmerLoader |

---

### Phase 2: WhatsApp + Ticketing (Weeks 3–5)

**Week 3 — WhatsApp Integration**
| Task | Details |
|------|---------|
| BSP integration | WhatsAppServiceInterface + Twilio/360dialog implementation |
| Webhook handler | Inbound message processing, signature verification |
| Idempotency | Redis lock + DB unique on wamid |
| Message storage | whatsapp_messages table, media upload to S3 |
| Outbound sending | Free-form + template sending, session window check |
| Delivery tracking | Status callbacks, retry with backoff |

**Week 4 — Ticketing Core**
| Task | Details |
|------|---------|
| Ticket CRUD | Create from inbound message, status transitions, validation |
| Assignment | Manual assign/reassign, basic round-robin routing |
| Tags & notes | Tag management, internal notes, ticket timeline |
| Flutter: Inbox | TicketCard component, inbox list with filters, pull-to-refresh |
| Flutter: Ticket Detail | Chat view with message bubbles, action bottom sheet |

**Week 5 — Ticketing Advanced**
| Task | Details |
|------|---------|
| Sticky owner | Route returning contacts to previous supervisor |
| Escalation flow | Escalate + reason, admin takeover, reassign |
| SLA policies | CRUD, breach detection job (every minute), warning notifications |
| Overflow rules | Max tickets per supervisor, overflow to admin queue |
| Flutter: Escalation | Escalation UI, SLA timer pill component |
| Flutter: Real-time | WebSocket ticket updates in inbox |

---

### Phase 3: Students CRM + Teachers (Weeks 6–7)

**Week 6 — Students & Guardians**
| Task | Details |
|------|---------|
| Student CRUD | Add/edit/disable, status management |
| Guardian CRUD | WhatsApp number validation, E.164 normalization |
| Linking | Guardian-student M2M, contact resolution from WhatsApp |
| Student timeline | Messages, notes, sessions — combined API |
| Flutter: Students | List, detail with tabs (timeline/messages/sessions/notes), forms |

**Week 7 — Teachers + Bulk Import**
| Task | Details |
|------|---------|
| Teacher CRUD | Add/edit, status toggle |
| Bulk import | Excel upload, validation, preview, conflict resolution job |
| Phone validation | WhatsApp number verification via BSP API |
| Flutter: Teachers | List, add/edit form |
| Flutter: Import | Upload + preview + confirm flow |

---

### Phase 4: Timetables + Reminders (Weeks 8–10)

**Week 8 — Timetable Engine**
| Task | Details |
|------|---------|
| Schedule CRUD | Create recurring schedule, link student/class_entity + teacher |
| Class entities | Generic grouping CRUD, student assignment |
| Conflict checker | Prevent teacher double-booking |
| Flutter: Schedules | List/calendar toggle, create form (stepped) |

**Week 9 — Session Generation + Exceptions**
| Task | Details |
|------|---------|
| Session generation | Weekly cron job + manual trigger API |
| Session status | upcoming/done/postponed/cancelled transitions |
| Exceptions | Cancel specific date, reschedule, time change |
| Flutter: Sessions | List, detail, cancel/reschedule modals |

**Week 10 — Reminders**
| Task | Details |
|------|---------|
| Reminder policies | CRUD, template linking, enable/disable/toggle |
| Reminder job creation | Daily cron, idempotency keys |
| Send + retry | SendReminderJob with backoff, delivery tracking |
| Delivery log | Status dashboard, failed queue, manual retry |
| Flutter: Reminders | Policy list, delivery log, retry button |

---

### Phase 5: Admin + Polish (Weeks 11–12)

**Week 11 — Admin Features**
| Task | Details |
|------|---------|
| User management | CRUD, role assignment, shift management |
| Routing rules | CRUD, algorithm selection, conditions |
| Audit log | Immutable logging, queryable API |
| Push notifications | FCM integration, notification preferences |
| Flutter: Admin screens | Users, routing, audit log, settings |

**Week 12 — Testing + Launch Prep**
| Task | Details |
|------|---------|
| Integration tests | Webhook idempotency, SLA breach, reminder dedupe |
| E2E flows | Full ticket lifecycle, session → reminder → delivery |
| Bug fixes | Stabilization sprint |
| Documentation | API docs (Scribe/Swagger), deployment guide |
| Staging deployment | Docker + cloud deploy, BSP webhook registration |

---

## 6.2 V1 Plan (Months 4–6)

### Month 4: Analytics + Advanced Routing

| Week | Deliverables |
|------|-------------|
| 13 | Analytics backend: KPI queries, response time calculations, SLA compliance |
| 14 | Analytics frontend: Dashboard with fl_chart, supervisor performance cards |
| 15 | Advanced routing: tag-based, time-based, skill matching (no academic fields) |
| 16 | Routing rules UI: drag-to-reorder priorities, condition builder |

### Month 5: Offline + Performance

| Week | Deliverables |
|------|-------------|
| 17 | Offline mode: Hive local cache, action queue, sync on reconnect |
| 18 | Performance optimization: pagination, eager loading, query caching |
| 19 | Search: full-text search (PostgreSQL tsvector or Meilisearch) |
| 20 | Biometric auth, notification grouping, deep linking |

### Month 6: Polish + Scale

| Week | Deliverables |
|------|-------------|
| 21 | Advanced SLA: per-category, auto-escalation chains, SLA reports |
| 22 | Template management: create/edit templates, BSP sync, preview |
| 23 | Feature flags: LaunchDarkly or config-based, safe rollouts |
| 24 | Load testing, security audit, production hardening, launch |

---

## 6.3 Success Criteria per Phase

| Phase | Criteria |
|-------|---------|
| Phase 1 | Auth works, role routing verified, CI green |
| Phase 2 | Inbound WhatsApp → ticket created → supervisor sees in app → replies → parent receives |
| Phase 3 | Student/guardian CRUD, contact resolution from WhatsApp, bulk import works |
| Phase 4 | Schedule → sessions auto-generated → reminders sent → delivery logged |
| Phase 5 | Full admin panel, audit trail, E2E test passing, staging live |
| V1 | Analytics dashboard, offline mode, advanced routing, production ready |
