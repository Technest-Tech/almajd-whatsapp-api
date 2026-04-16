# Almajd Academy - Deployment Credentials & Notes

## Server & Domain
- **Server IP:** `64.225.63.111`
- **Live Domain:** `cloud.almajd.info` → resolves to server IP ✅ (used by mobile app)
- **Note:** `whatsapp.almajd.info` is listed in older notes but is **not in DNS** — do not use it.

## Firebase Configuration
- **App ID:** `1:449886354083:android:132e69019a227039421d16`
- **Project Number:** `449886354083`
- **Sender ID:** `449886354083`
- **FCM API V1:** Enabled
- *Note: Firebase files are placed in the directory.*

## Integrations
- **WhatsApp:** Twilio will be used. Access key to be provided later.
- **GitHub:** Access to be provided for deployment synchronization.

## Domains (verify in server Nginx / `.env`)
- **API / App / Reverb (production):** `cloud.almajd.info` → server IP `64.225.63.111` ✅
  - Set `APP_URL=https://cloud.almajd.info` in `/var/www/almajd/backend/.env`
  - Mobile app `ApiClient._baseUrl = 'https://cloud.almajd.info/api'` ← confirmed
- **`whatsapp.almajd.info`** — not in DNS; ignore for now.

## WasenderAPI Webhook URL
```
https://cloud.almajd.info/api/webhooks/wasender
```
Paste this in: Wasender Dashboard → Sessions → Edit → Webhook URL

## Next Deployment Steps (first-time)
1. Setup SSH connection to `root@64.225.63.111`.
2. Locate the Firebase config files (`google-services.json`, `firebase-adminsdk.json`) and place them in the correct Flutter/Laravel directories.
3. Configure Twilio credentials in the Laravel backend once provided.
4. Prepare Laravel production environment (`.env`, database, migrations).
5. Prepare Flutter builds.

---

## Deploy backend to the server (after `git push`)

SSH in, go to the app directory (path may be `/var/www/almajd` or similar — confirm with `ls` on the server), then:

```bash
ssh root@64.225.63.111
cd /var/www/almajd   # or your actual clone path

git pull origin main

cd backend
composer install --no-dev --optimize-autoloader
php artisan migrate --force
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan event:cache
```

Restart long-running PHP processes so workers pick up code and `.env`:

```bash
# CRITICAL: Restart PHP-FPM to clear OPcache (without this, webhooks use stale code!)
sudo systemctl restart php8.2-fpm

# Restart queue worker and WebSocket server (Supervisor)
sudo supervisorctl restart almajd-worker:almajd-worker_00
sudo supervisorctl restart almajd-reverb:almajd-reverb_00
# Optional: scheduler / other program names you configured
```

Cron: ensure the Laravel scheduler runs (e.g. `* * * * * cd /path/to/backend && php artisan schedule:run`).

**After this release:** `sessions:rebalance` is registered — if you added it to `routes/console.php` schedule, only `schedule:run` is required; otherwise run `php artisan sessions:rebalance` manually or add to cron.

## Deploy mobile app
- Point build to the **production API / WebSocket** URLs (same host as `APP_URL` / Reverb).
- Drop in **`google-services.json`** (Android) and iOS Firebase options as per Flutter/Firebase docs.
- Build release: `flutter build apk` / `flutter build ipa` (or CI), then upload to Play Console / App Store Connect.

## GitHub → server
- Repo: sync server clone with `git pull origin main` (SSH key on server with read access to GitHub).
- **Do not commit** `.env`, Firebase private keys, or Twilio secrets; keep them only on the server and in secure storage.
