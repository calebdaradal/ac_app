# OneSignal Android Push Notification Setup

## Why This Is Needed
OneSignal uses Firebase Cloud Messaging (FCM) to send push notifications to Android devices. Without configuring FCM, OneSignal cannot deliver notifications even if everything else is set up correctly.

## Step-by-Step Setup

### Step 1: Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project" or select existing project
3. Follow the setup wizard
4. Enable Google Analytics (optional but recommended)

### Step 2: Add Android App to Firebase
1. In Firebase Console, click "Add app" → Android
2. Enter your package name: `com.ascendocapital.app` (check `android/app/build.gradle.kts` for actual package)
3. Register the app
4. Download `google-services.json` file

### Step 3: Add google-services.json to Your Flutter Project
1. Place `google-services.json` in `android/app/` directory
2. Make sure the file is named exactly `google-services.json` (lowercase)

### Step 4: Update Android Build Files

**Update `android/settings.gradle.kts` (project-level):**
Add the Google Services plugin to the plugins block:
```kotlin
plugins {
    // ... existing plugins
    id("com.google.gms.google-services") version "4.4.0" apply false
}
```

**Update `android/app/build.gradle.kts` (app-level):**
Add the Google Services plugin to the plugins block:
```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")  // Add this line
}
```

**Note:** I've already updated these files for you! Just make sure `google-services.json` is in place.

### Step 5: Enable Firebase Cloud Messaging API V1
1. In Firebase Console → Project Settings → Cloud Messaging
2. Verify "Firebase Cloud Messaging API (V1)" shows "Enabled" ✅
3. If it's disabled, click the three-dot menu → "Open in Cloud Console" → Enable

### Step 6: Generate Service Account JSON
1. In Firebase Console → Project Settings → Service Accounts tab
2. Click "Generate new private key"
3. Click "Generate key" in the confirmation dialog
4. Save the downloaded `.json` file securely (e.g., `firebase-service-account.json`)
5. **Important:** Keep this file secure - it contains sensitive credentials

### Step 7: Configure OneSignal with Service Account
1. Go to OneSignal Dashboard → Settings → Platforms → Google Android (FCM)
2. Click "Activate" or "Edit" if already activated
3. Under "Service Account JSON", click "Upload" or "Choose File"
4. Upload the Service Account JSON file you downloaded
5. Ensure "Firebase Cloud Messaging API (V1)" is selected (not Legacy)
6. Click "Save"

### Step 8: Rebuild Your App
After configuring FCM, you need to rebuild your APK:
```bash
flutter clean
flutter build apk --release
```

### Step 9: Test
1. Install the new APK on your phone
2. Log in to your app
3. Check if device token is stored in `device_tokens` table
4. Try sending a test notification from OneSignal Dashboard

## Quick Checklist
- [ ] Firebase project created
- [ ] Android app added to Firebase (package: `com.ascendocapital.app`)
- [ ] `google-services.json` downloaded and placed in `android/app/`
- [ ] Build files updated with Google Services plugin
- [ ] Firebase Cloud Messaging API V1 enabled
- [ ] Service Account JSON generated from Firebase
- [ ] Service Account JSON uploaded to OneSignal
- [ ] App rebuilt with new configuration
- [ ] Device token registered in database
- [ ] Test notification sent successfully

## Troubleshooting

### Issue: "google-services.json not found"
- Make sure file is in `android/app/` directory
- Check file name is exactly `google-services.json` (lowercase)
- Rebuild the app

### Issue: "Package name mismatch"
- Check package name in `android/app/build.gradle.kts` matches Firebase
- Update Firebase app package name if needed

### Issue: "Notifications still not working"
- Verify Service Account JSON is uploaded correctly in OneSignal
- Check Firebase Cloud Messaging API V1 is enabled (not Legacy)
- Ensure app has notification permissions on device
- Rebuild and reinstall the app
- Check OneSignal dashboard for delivery status

## Alternative: OneSignal Setup Wizard
OneSignal also provides a setup wizard that can help automate some of these steps:
1. Go to OneSignal Dashboard → Settings → Platforms
2. Click "Google Android (FCM)"
3. Follow the setup wizard if available

