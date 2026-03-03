# AI Implementation Guide
# Academy WhatsApp Communication & Operations System

## Your 3 Reference Files

| File | Purpose |
|------|---------|
| `ai_implementation_guide.md` | Rules, context block, verification commands, error fixes (THIS FILE) |
| `ai_prompts_part1.md` | Week 1–6 detailed prompts (backend + Flutter) |
| `ai_prompts_part2.md` | Week 7–12 detailed prompts + V1 post-MVP prompts |
| `progress.md` | YOUR daily progress tracker — update this as you go |

---

## STEP 1: ALWAYS START EVERY AI CHAT WITH THIS

Copy this EXACTLY at the top of every new AI chat session:

```
You are a senior Laravel 11 + Flutter engineer building the
"Academy WhatsApp Communication & Operations System" for Almajd Academy.

TECH STACK:
- Backend: Laravel 11, PHP 8.2+, PostgreSQL 15, Redis 7, Laravel Reverb (WebSockets), Laravel Queue
- Mobile: Flutter 3.x, Dart 3.x, flutter_bloc, GoRouter, Dio, GetIt+injectable, freezed, Hive
- Auth: JWT via tymon/jwt-auth, Spatie laravel-permission for RBAC

CRITICAL CONSTRAINTS — apply to every line of code:
1. NO grade/level/branch/group fields anywhere
2. NO teacher subject/level/group assignments
3. Zero business logic in Controllers — all logic in Services
4. All JSON responses: { "success": bool, "data": {}, "message": "", "meta": {} }
5. PHP 8.2 backed Enums for ALL status fields (never plain strings)
6. PHPDoc on every public Service method
7. Write PHPUnit Feature tests alongside every backend feature
8. Flutter: clean architecture (data/domain/presentation per feature folder)
9. Flutter: Arabic RTL-first, Material 3, dark mode support
10. Flutter: flutter_bloc for all state — never setState in screens

PROJECT ROOT: /Users/ahmedomar/Documents/technest/AlmajdAcademy/Almajd-Whatsapp-ApiApp
BACKEND DIR:  .../Almajd-Whatsapp-ApiApp/backend
MOBILE DIR:   .../Almajd-Whatsapp-ApiApp/mobile

TODAY'S TASK: [PASTE TASK FROM PROMPT FILE]
```

---

## STEP 2: PICK YOUR CURRENT WEEK'S PROMPT

- **Weeks 1–6** → open `ai_prompts_part1.md`
- **Weeks 7–12** → open `ai_prompts_part2.md`
- Copy the full prompt for your current week's task
- Paste AFTER the universal context block above

---

## STEP 3: VERIFY AFTER EVERY AI OUTPUT

```bash
# BACKEND (run from /backend folder)
php artisan test                     # Must: 0 failures
php artisan migrate --pretend        # Must: no errors
php artisan route:list               # Must: new routes visible
./vendor/bin/phpstan analyse app     # Must: no errors

# FLUTTER (run from /mobile folder)
flutter analyze                      # Must: 0 warnings
flutter test                         # Must: 0 failures
```

**NEVER move to the next week if any check fails.**

---

## STEP 4: CONTINUING A SESSION (RESUME PROMPT)

When starting a new chat after a break:

```
I'm continuing the Academy WhatsApp system implementation.

PROGRESS:
[paste your progress.md content]

LAST COMPLETED: [task name]
TODAY: [next task from prompt file]

SPEC CONTEXT:
[paste only the section from docs/ mentioned in the prompt]
```

---

## ERROR FIX PROMPTS

**Logic in controller:**
```
You put business logic in the controller. Move ALL of it to [Name]Service.
Controller should ONLY: call Form Request validation, call service, return response.
Refactor now.
```

**Wrong field name:**
```
Wrong field name. The correct schema is:
[paste table from data_model.md]
Fix all references.
```

**Plain string status:**
```
Replace plain string statuses with PHP 8.1 backed enum.
Create app/Enums/[Name]Status.php with cases: [list].
Cast it in the model: protected $casts = ['status' => [Name]Status::class];
```

**N+1 queries:**
```
This has N+1 queries. Add ->with([relations]) to all list queries.
Check every foreach for lazy loading.
```

**Missing Form Request:**
```
Create app/Http/Requests/[Name]Request.php with validation rules for all fields.
Use it: public function method([Name]Request $request)
```

**Missing tests:**
```
Write PHPUnit Feature tests covering:
1. Happy path (valid data → expected response)
2. Validation error (invalid data → 422)
3. No auth (no token → 401)
4. Wrong role (wrong role → 403)
```

**Flutter: no loading/error state:**
```
The screen doesn't handle loading and error states.
Add: CircularProgressIndicator when loading, SnackBar on error,
EmptyState widget when list is empty. Use BlocConsumer properly.
```

**Flutter: hardcoded string:**
```
Don't hardcode Arabic strings in widgets.
Move all text to core/l10n/app_ar.arb and use AppLocalizations.of(context).key
```

---

## GOLDEN RULES

| # | Rule |
|---|------|
| 1 | Always paste the universal context block above at the start of every chat |
| 2 | One week = one set of sessions. Don't mix weeks in one prompt. |
| 3 | Always ask for tests: add "Also write Feature tests for every method" |
| 4 | Run verification after every output before pasting the next prompt |
| 5 | Keep constraints visible: paste the constraint list in every backend prompt |
| 6 | Update progress.md after completing each task |
| 7 | Never skip a week — each week builds on the previous |
