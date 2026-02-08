# Package Name Update Guide

## ✅ What Was Changed

The package name has been changed from `com.example.user` to `com.pasahero.app` to avoid SHA1 conflicts with other apps.

## 📝 Files Updated

- ✅ `android/app/build.gradle.kts` - namespace and applicationId
- ✅ `android/app/src/main/kotlin/com/pasahero/app/MainActivity.kt` - package declaration and file location
- ✅ `lib/firebase_options.dart` - iOS and macOS bundle IDs
- ✅ `macos/Runner/Configs/AppInfo.xcconfig` - macOS bundle identifier
- ✅ `linux/CMakeLists.txt` - Linux application ID
- ✅ `ios/Runner.xcodeproj/project.pbxproj` - iOS bundle identifiers
- ✅ `macos/Runner.xcodeproj/project.pbxproj` - macOS bundle identifiers

## 🔥 IMPORTANT: Update Firebase Console

You **MUST** update your Firebase project with the new package name:

### Step 1: Add New Android App in Firebase

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **pasaherodb**
3. Click ⚙️ → **Project Settings**
4. Scroll to **"Your apps"** section
5. Click **"Add app"** → Select **Android**
6. Enter the new package name: `com.pasahero.app`
7. Register the app
8. **Download the new `google-services.json`**
9. **Replace** `user/android/app/google-services.json` with the new file

### Step 2: Update SHA1 Fingerprint

1. Get your SHA1 fingerprint:
   ```bash
   cd user/android
   ./gradlew signingReport
   ```
   Copy the SHA1 from the `debug` variant.

2. In Firebase Console:
   - Go to your **new Android app** (with package `com.pasahero.app`)
   - Click **"Add fingerprint"**
   - Paste your SHA1
   - Click **Save**

### Step 3: Update Google Cloud Console OAuth Client

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: **pasaherodb**
3. Go to **APIs & Services** → **Credentials**
4. Find or create an **Android OAuth 2.0 Client ID**
5. Set:
   - **Package name**: `com.pasahero.app`
   - **SHA-1 certificate fingerprint**: (your SHA1 from Step 2)
6. Click **Save**

### Step 4: Update iOS App (if needed)

If you're using iOS:

1. In Firebase Console → **Project Settings** → **Your apps**
2. Find your **iOS app** or create a new one
3. Update the **Bundle ID** to: `com.pasahero.app`
4. Download the new `GoogleService-Info.plist`
5. Replace `user/ios/Runner/GoogleService-Info.plist`

### Step 5: Regenerate Firebase Options (Optional but Recommended)

After updating Firebase, regenerate your `firebase_options.dart`:

```bash
cd user
flutterfire configure
```

This will update all the Firebase configuration files automatically.

### Step 6: Clean and Rebuild

```bash
cd user
flutter clean
flutter pub get
flutter run
```

## ⚠️ Important Notes

1. **Do NOT delete the old app** in Firebase Console until you've verified the new one works
2. The old `google-services.json` will **NOT work** with the new package name
3. You **MUST** download the new `google-services.json` from Firebase Console
4. Make sure the SHA1 fingerprint matches your debug keystore
5. The OAuth client in Google Cloud Console must have the correct package name and SHA1

## 🔍 Verify the Changes

After updating Firebase:

1. Check that `user/android/app/google-services.json` has:
   ```json
   "package_name": "com.pasahero.app"
   ```

2. Verify your app builds:
   ```bash
   flutter build apk --debug
   ```

3. Test Google Sign-In to ensure it works with the new package name

## 🆘 Troubleshooting

If you get errors:

1. **"OAuth client not found"**: Make sure you've created/updated the OAuth client in Google Cloud Console with the new package name
2. **"SHA1 mismatch"**: Verify your SHA1 in Firebase Console matches the one from `./gradlew signingReport`
3. **"Package name mismatch"**: Ensure all package names match exactly:
   - `android/app/build.gradle.kts` → `applicationId`
   - Firebase Console → Android app package name
   - Google Cloud Console → OAuth client package name
