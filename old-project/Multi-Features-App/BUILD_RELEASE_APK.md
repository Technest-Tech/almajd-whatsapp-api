# Building a Secured Release APK

This guide will help you create a signed, secured release APK for the Multi-Features App.

## Prerequisites

1. **Java JDK** (version 11 or higher) - Required for keytool
2. **Flutter SDK** - Make sure Flutter is installed and configured
3. **Android SDK** - Required for building Android apps

## Step 1: Create a Keystore

### Option A: Using the Automated Script (Recommended)

1. Navigate to the android directory:
   ```bash
   cd Multi-Features-App/android
   ```

2. Make the script executable:
   ```bash
   chmod +x create-keystore.sh
   ```

3. Run the script:
   ```bash
   ./create-keystore.sh
   ```

4. Follow the prompts to enter:
   - Keystore password (min 6 characters)
   - Key password (can be same as keystore password)
   - Key alias (default: upload)
   - Your name
   - Organization details
   - Location details

### Option B: Manual Keystore Creation

1. Navigate to the android directory:
   ```bash
   cd Multi-Features-App/android
   ```

2. Run the keytool command:
   ```bash
   keytool -genkey -v -keystore keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

3. Enter the required information when prompted:
   - Keystore password
   - Key password
   - Your name and organization details

## Step 2: Create key.properties File

1. Copy the example file:
   ```bash
   cp key.properties.example key.properties
   ```

2. Edit `key.properties` and fill in your actual values:
   ```properties
   storePassword=YOUR_KEYSTORE_PASSWORD
   keyPassword=YOUR_KEY_PASSWORD
   keyAlias=upload
   storeFile=../keystore.jks
   ```

   **Important:** Replace the placeholder values with your actual passwords and ensure the path to `keystore.jks` is correct.

## Step 3: Verify Security

Make sure these files are in `.gitignore` (already configured):
- `keystore.jks`
- `key.properties`
- `*.jks`
- `*.keystore`

**⚠️ NEVER commit these files to version control!**

## Step 4: Build the Release APK

### Build APK (for direct installation)

```bash
cd Multi-Features-App
flutter build apk --release
```

The APK will be located at:
```
build/app/outputs/flutter-apk/app-release.apk
```

### Build App Bundle (for Google Play Store)

```bash
cd Multi-Features-App
flutter build appbundle --release
```

The AAB will be located at:
```
build/app/outputs/bundle/release/app-release.aab
```

## Step 5: Verify the APK is Signed

You can verify that your APK is properly signed using:

```bash
# For APK
jarsigner -verify -verbose -certs build/app/outputs/flutter-apk/app-release.apk

# Or using apksigner (Android SDK tool)
apksigner verify --verbose build/app/outputs/flutter-apk/app-release.apk
```

## Security Features Enabled

The release build includes:

1. **Code Obfuscation** - Enabled via ProGuard
2. **Resource Shrinking** - Removes unused resources
3. **Code Shrinking** - Removes unused code
4. **Signed APK** - Cryptographically signed with your keystore

## Troubleshooting

### Error: "key.properties not found"

- Make sure `key.properties` exists in the `android/` directory
- Check that the file path in `key.properties` points to the correct keystore location

### Error: "Keystore was tampered with, or password was incorrect"

- Verify your passwords in `key.properties` are correct
- Make sure there are no extra spaces or special characters

### Error: "Execution failed for task ':app:signReleaseBundle'"

- Ensure the keystore file exists at the path specified in `key.properties`
- Verify all passwords are correct
- Check that the key alias matches

### Build fails with ProGuard errors

- Check `android/app/proguard-rules.pro` for any missing rules
- You may need to add keep rules for specific classes if they're being removed

## Storing Your Keystore Securely

**Important Security Notes:**

1. **Backup your keystore** - Store it in a secure location (password manager, encrypted drive)
2. **Never lose your keystore** - You cannot update your app on Google Play without it
3. **Keep passwords safe** - Store them securely, not in plain text files
4. **Use different keystores** - Use separate keystores for different apps/environments

## Updating the App Version

Before building a new release, update the version in `pubspec.yaml`:

```yaml
version: 1.0.1+2  # Format: version_name+build_number
```

Then rebuild:
```bash
flutter clean
flutter pub get
flutter build apk --release
```

## Additional Security Recommendations

1. **Enable R8 Full Mode** (already enabled via `isMinifyEnabled = true`)
2. **Review ProGuard rules** - Add keep rules only when necessary
3. **Test the release build** - Always test the release APK before distribution
4. **Use App Bundle** - For Google Play, use AAB format for better optimization

## Quick Reference

```bash
# Create keystore (first time only)
cd android && ./create-keystore.sh

# Build release APK
flutter build apk --release

# Build release App Bundle (for Play Store)
flutter build appbundle --release

# Clean build
flutter clean && flutter pub get && flutter build apk --release
```







