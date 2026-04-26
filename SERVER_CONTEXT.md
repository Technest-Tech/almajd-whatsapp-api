# Almajd Academy — Server & Project Context

> This file exists so that any AI assistant or developer can immediately understand
> the full system, access the server, and continue work without re-discovering everything.

---

## 🖥️ Production Server

| Property     | Value                          |
|--------------|-------------------------------|
| Provider     | DigitalOcean                   |
| IP Address   | `64.225.63.111`                |
| SSH User     | `root`                         |
| SSH Auth     | Key-based (no password needed) |
| Domain       | `https://cloud.almajd.info`    |
| OS           | Ubuntu 22.04 LTS               |
| Web Server   | Nginx + PHP-FPM                |

### SSH Access
```bash
ssh root@64.225.63.111
```

### Run a remote PHP script
```bash
scp /tmp/myscript.php root@64.225.63.111:/tmp/myscript.php && \
ssh root@64.225.63.111 "php /tmp/myscript.php && rm /tmp/myscript.php"
```

---

## 📁 Backend (Laravel 12)

| Property       | Value                                |
|----------------|--------------------------------------|
| Location       | `/var/www/almajd/backend/`           |
| Framework      | Laravel 12                           |
| PHP Version    | PHP 8.2                              |
| Database       | MySQL — `almajd_whatsapp` (local)    |
| Queue Driver   | Database                             |
| API Base URL   | `https://cloud.almajd.info/api`      |

### Key Artisan Commands
```bash
cd /var/www/almajd/backend

# Sync legacy calendar sessions for next 7 days
php artisan calendar:sync-legacy 7

# Generate class sessions for all students (3 months)
php artisan sessions:generate --months=3

# Run the WhatsApp reminder scheduler
php artisan reminders:auto-schedule

# Run the queue worker
php artisan queue:work --queue=high,default --sleep=3 --tries=3
```

### Laravel Scheduler (runs via cron every minute)
Configured in: `/var/www/almajd/backend/routes/console.php`
- `reminders:auto-schedule` → every 5 minutes
- `SendSessionRemindersJob` → every minute
- `sessions:generate --months=3` → daily at 02:00
- `calendar:sync-legacy 7` → daily at 00:00
- `SendReportNudgeJob` → hourly

> ⚠️ `sessions:rebalance` has been **removed**. Supervisor assignment is now fully shift-based via `ShiftService`. Each supervisor automatically sees all sessions that fall within their configured shift window — no rebalancing needed.

---

## 🗄️ Databases

### New System Database
- **Host:** localhost (on production server)
- **Name:** `almajd_whatsapp`
- **User/Pass:** See `/var/www/almajd/backend/.env`

### Old Legacy Database (Read-Only Remote)
- **Host:** `138.68.46.231`
- **Name:** `almajd_certificates`
- **Used for:** Pulling student data and calendar reservations

---

## 📱 Mobile App (Flutter)

| Property       | Value                                         |
|----------------|-----------------------------------------------|
| Location       | `./mobile/` (in this repo)                    |
| Flutter SDK    | `~/fvm/default/bin/flutter` (on dev machine)  |
| API Target     | `https://cloud.almajd.info/api`               |
| Package ID     | `com.almajd.academy.almajd_mobile`            |
| Signing Key    | `android/app/upload-keystore.jks`             |
| Key Alias      | `upload`                                      |
| Key Properties | `android/key.properties`                      |

### Build Release APK
```bash
cd mobile
~/fvm/default/bin/flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

---

## 🔗 Legacy System (Old System)

| Property   | Value                        |
|------------|------------------------------|
| IP         | `138.68.46.231`              |
| Domain     | `multi.almajd.info`          |
| Purpose    | Legacy calendar + old data   |
| Status     | Read-only reference only     |

---

## 🤖 WhatsApp Integration

- **Provider:** Wasender API
- **Webhook URL:** `https://cloud.almajd.info/api/webhook/wasender`
- **Config File:** `/var/www/almajd/backend/config/whatsapp.php`
- **Key Jobs:**
  - `ProcessWasenderInboundMessageJob` — handles replies from teachers/students
  - `SendSessionRemindersJob` — sends pending reminder messages
  - `SendReportNudgeJob` — nudges teachers to submit session reports

---

## 📊 Current System State (as of April 2026)

- **Total Students:** 1,631
- **Students with WhatsApp:** 1,481 (90.8%)
- **Missing WhatsApp (ghost profiles):** 150
- **Reminder Cleanliness:** ~85% of upcoming sessions fully automated

### Data Notes
- Students were migrated from legacy `almajd_certificates` DB
- ~428 students were matched via fuzzy name matching
- ~150 legacy calendar names could NOT be auto-matched (require manual admin input)
- Admin must add phone numbers manually for these 150 from the Students dashboard

---

## 📂 Key Files in This Repo

| File | Purpose |
|------|---------|
| `backend/app/Console/Commands/AutoScheduleRemindersCommand.php` | Core reminder scheduling logic |
| `backend/app/Services/LegacyCalendarSyncService.php` | Syncs legacy calendar → class_sessions |
| `backend/app/Jobs/ProcessWasenderInboundMessageJob.php` | Handles all inbound WhatsApp messages |
| `backend/app/Jobs/SendSessionRemindersJob.php` | Dispatches pending reminder messages |
| `backend/routes/console.php` | All scheduled cron tasks |
| `backend/routes/api.php` | All REST API routes |
| `mobile/lib/` | Flutter mobile app source |
