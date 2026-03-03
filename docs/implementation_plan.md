# Academy WhatsApp Communication & Operations System — Master Plan

> **Tech Stack**: Laravel 11 (Backend) · Flutter (Mobile) · PostgreSQL · Redis · WebSockets
> **Project Dir**: `/Users/ahmedomar/Documents/technest/AlmajdAcademy/Almajd-Whatsapp-ApiApp`

This is the **index document**. The full specification is split across the files below.

## Document Index

| # | Document | Contents |
|---|----------|----------|
| 1 | [architecture.md](file:///Users/ahmedomar/.gemini/antigravity/brain/bf0fb8f8-eec2-43b2-a8a2-26a2b2875937/architecture.md) | System architecture, module breakdown, directory structure, layer responsibilities |
| 2 | [data_model.md](file:///Users/ahmedomar/.gemini/antigravity/brain/bf0fb8f8-eec2-43b2-a8a2-26a2b2875937/data_model.md) | Complete ERD (all tables, fields, relationships, indexes) |
| 3 | [api_spec.md](file:///Users/ahmedomar/.gemini/antigravity/brain/bf0fb8f8-eec2-43b2-a8a2-26a2b2875937/api_spec.md) | Full REST API specification with endpoints, request/response examples |
| 4 | [flutter_app.md](file:///Users/ahmedomar/.gemini/antigravity/brain/bf0fb8f8-eec2-43b2-a8a2-26a2b2875937/flutter_app.md) | Flutter app structure, navigation map, screen specs, component library, UI/UX |
| 5 | [scheduler_and_jobs.md](file:///Users/ahmedomar/.gemini/antigravity/brain/bf0fb8f8-eec2-43b2-a8a2-26a2b2875937/scheduler_and_jobs.md) | Job scheduler, reminder generation, session generation, retry policies |
| 6 | [roadmap.md](file:///Users/ahmedomar/.gemini/antigravity/brain/bf0fb8f8-eec2-43b2-a8a2-26a2b2875937/roadmap.md) | MVP (10–12 weeks) & V1 (4–6 months) roadmaps with milestones |
| 7 | [testing_devops.md](file:///Users/ahmedomar/.gemini/antigravity/brain/bf0fb8f8-eec2-43b2-a8a2-26a2b2875937/testing_devops.md) | Testing strategy, DevOps, NFRs, coding standards, extensibility points |

## Critical Constraints (Enforced Everywhere)

1. **No academic fields**: grade, level, branch, group are excluded from all entities
2. **No teacher subject/level/group assignments**: teachers have no course-level binding
3. **Mobile-only admin**: no web dashboard — everything is in the Flutter app
4. **Single login system** with role-based dashboards (Supervisor / Senior Supervisor / Admin)
5. **WhatsApp-first**: parents/students interact only via WhatsApp

## Verification Plan

Since this is a **planning/specification deliverable** (no code yet), verification is:
1. **User review** of all 7 documents for completeness, accuracy, and alignment with requirements
2. **Constraint compliance check**: grep all docs to confirm no mention of grade/level/branch/group as data fields
3. After approval, code implementation will follow the roadmap in `roadmap.md`
