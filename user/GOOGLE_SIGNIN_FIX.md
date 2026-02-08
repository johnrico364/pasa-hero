# Fix Google Sign-In "invalid_client" Error

## The Problem
The error "Access blocked: Authorization Error - Error 401: invalid_client" occurs because:
1. The Web OAuth Client ID is not configured in the code (`_getWebClientId()` returns `null`)
2. Android Google Sign-In **requires** the Web OAuth Client ID as `serverClientId`

## Solution: Get and Configure Web OAuth Client ID

### Step 1: Get Your Web OAuth Client ID from Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **pasahero-db**
3. Click ⚙️ → **Project Settings**
4. Scroll to **"Your apps"** section
5. Find your **Web app** (or create one if it doesn't exist)
6. In **"SDK setup and configuration"**, look for **"OAuth client ID"**
7. Copy the Client ID (format: `464857061623-xxxxx.apps.googleusercontent.com`)

### Step 2: Update the Code

After getting the Web Client ID, update `user/lib/core/services/auth_service.dart`:

Find the `_getWebClientId()` method (around line 29) and replace `null` with your actual Web Client ID:

```dart
String? _getWebClientId() {
  // Replace with your actual Web OAuth Client ID from Firebase Console
  const String? webClientId = 'YOUR_WEB_CLIENT_ID_HERE.apps.googleusercontent.com';
  
  return webClientId;
}
```

### Step 3: Verify Google Cloud Console Configuration

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: **pasahero-db**
3. Go to **APIs & Services** → **Credentials**
4. Find your **OAuth 2.0 Client IDs**

**For Android OAuth Client:**
- Package name: `com.pasahero.ap` ✅
- SHA-1: `F6:47:B2:87:5E:11:AD:46:F5:69:23:9A:B3:7A:81:A5:D0:F1:E3:B5` ✅
- SHA-256: `D3:FB:3B:ED:DA:DE:20:4B:53:E9:97:50:0C:16:FE:65:3E:A8:FA:AE:31:C0:45:BE:E1:6B:EC:D0:40:A5:BC:40` ✅

**For Web OAuth Client:**
- Make sure it exists
- Note the Client ID (this is what you need for `_getWebClientId()`)

### Step 4: Enable Google Sign-In in Firebase

1. Firebase Console → **Authentication** → **Sign-in method**
2. Click on **Google**
3. Enable it
4. Make sure the **Web OAuth Client ID** and **Web OAuth Client Secret** are configured
5. Click **Save**

### Step 5: Rebuild Your App

```bash
cd user
flutter clean
flutter pub get
flutter run
```

## Important Notes

1. **Package Name Must Match**: `com.pasahero.ap` must match in:
   - `android/app/build.gradle.kts` ✅
   - Firebase Console Android app ✅
   - Google Cloud Console OAuth client ✅

2. **SHA1 Must Match**: The SHA1 in Google Cloud Console must match your debug keystore

3. **Web Client ID is Required**: Android Google Sign-In **must** use the Web OAuth Client ID as `serverClientId`

4. **Both SHA1 and SHA256**: You mentioned you added both - that's good, but the Web Client ID in code is the critical missing piece

## Quick Check List

- [ ] Web OAuth Client ID obtained from Firebase Console
- [ ] `_getWebClientId()` updated with actual Client ID
- [ ] Google Cloud Console Android OAuth client has correct package name and SHA1
- [ ] Google Sign-In enabled in Firebase Authentication
- [ ] App rebuilt after changes
