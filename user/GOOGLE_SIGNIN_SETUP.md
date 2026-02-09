# Google Sign-In Setup Guide

## The "invalid_client" Error Fix

The error "Access blocked: Authorization Error - Error 401: invalid_client" means the OAuth client is not properly configured in Google Cloud Console.

## Step-by-Step Fix:

### 1. Get Your SHA1 Fingerprint

**For Debug Build:**
```bash
cd android
./gradlew signingReport
```

Look for the SHA1 under `Variant: debug` → `SHA1:`

**Or manually:**
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

**For Release Build:**
```bash
keytool -list -v -keystore android/app/your-release-key.keystore -alias your-key-alias
```

### 2. Add SHA1 to Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **pasahero-78208**
3. Click ⚙️ → **Project Settings**
4. Scroll to **"Your apps"** → Select your **Android app**
5. Click **"Add fingerprint"**
6. Paste your SHA1 fingerprint
7. Click **"Save"**

### 3. Get Your Web OAuth Client ID

1. In Firebase Console → **Project Settings**
2. Scroll to **"Your apps"** → Select your **Web app**
3. In **"SDK setup and configuration"**, find **"OAuth client ID"**
4. Copy the Client ID (format: `66461159713-xxxxx.apps.googleusercontent.com`)

### 4. Configure Google Cloud Console

**IMPORTANT:** You must also configure this in Google Cloud Console:

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: **pasahero-78208**
3. Go to **APIs & Services** → **Credentials**
4. Find your **OAuth 2.0 Client IDs**
5. For your **Android** OAuth client:
   - Click **Edit**
   - Make sure **Package name** is: `com.example.user`
   - Add your **SHA1 fingerprint** in **"SHA-1 certificate fingerprint"**
   - Click **Save**
6. For your **Web** OAuth client:
   - Make sure it exists
   - Note the **Client ID** (you'll need this)

### 5. Update Your Code

The Web OAuth Client ID needs to be used in your app. Update `user/lib/core/services/auth_service.dart`:

Replace the `_getWebClientId()` method with your actual Web Client ID from step 3.

### 6. Enable Google Sign-In in Firebase

1. Firebase Console → **Authentication** → **Sign-in method**
2. Click on **Google**
3. Enable it
4. Add your **Web OAuth Client ID** and **Web OAuth Client Secret** (from Google Cloud Console)
5. Click **Save**

### 7. Verify Package Name

Make sure your package name matches exactly:
- In `android/app/build.gradle.kts`: `applicationId = "com.example.user"`
- In Firebase Console: Android app package name
- In Google Cloud Console: OAuth client package name

All three must match exactly!

### 8. Rebuild Your App

After making changes:
```bash
flutter clean
flutter pub get
flutter run
```

## Common Issues:

1. **SHA1 Mismatch**: Make sure you're using the correct SHA1 (debug vs release)
2. **Package Name Mismatch**: All package names must match exactly
3. **OAuth Client Not Created**: The OAuth client must exist in Google Cloud Console
4. **Web Client ID Missing**: You need the Web OAuth Client ID for Android Sign-In

## Quick Check:

Run this to verify your SHA1:
```bash
cd android
./gradlew signingReport
```

Then verify it matches what's in Firebase Console.
