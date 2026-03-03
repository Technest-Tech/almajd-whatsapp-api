# Almajd Academy - Deployment Credentials & Notes

## Server & Domain
- **Server IP:** `64.225.63.111`
- **Domain:** `whatsapp.almajd.info` (directs to IP)

## Firebase Configuration
- **App ID:** `1:449886354083:android:132e69019a227039421d16`
- **Project Number:** `449886354083`
- **Sender ID:** `449886354083`
- **FCM API V1:** Enabled
- *Note: Firebase files are placed in the directory.*

## Integrations
- **WhatsApp:** Twilio will be used. Access key to be provided later.
- **GitHub:** Access to be provided for deployment synchronization.

## Next Deployment Steps:
1. Setup SSH connection to `root@64.225.63.111`.
2. Locate the Firebase config files (`google-services.json`, `firebase-adminsdk.json`) and place them in the correct Flutter/Laravel directories.
3. Configure Twilio credentials in the Laravel backend once provided.
4. Prepare Laravel production environment (`.env`, database, migrations).
5. Prepare Flutter builds.
