# Code Review Summary - Configuration Check

## ✅ What's Working

1. **Firebase Initialization**: `main.dart` correctly uses `DefaultFirebaseOptions.currentPlatform`
2. **Google Sign-In Configuration**: 
   - `serverClientId` is set for all platforms (including web) ✅
   - Scopes include `['email', 'profile', 'openid']` ✅
   - Client ID in `auth_service.dart` matches `index.html` ✅
3. **Android Configuration**:
   - `google-services.json` is present ✅
   - SHA1 fingerprint matches: `f647b2875e11ad46f569239ab37a81a5d0f1e3b5` ✅
4. **Web Configuration**:
   - `index.html` has Google Sign-In client ID meta tag ✅

## ⚠️ Issues Found

### 1. **Project Mismatch** (CRITICAL)
- **Terminal shows**: New project `pasahero-d3fff` with app IDs:
  - Web: `1:414883959246:web:c80bcff782edf0f7d4db9f`
  - Android: `1:414883959246:android:3ccae32ac65416d6d4db9f`
  - iOS: `1:414883959246:ios:1f428368a06e8032d4db9f`

- **Current `firebase_options.dart` shows**: Old project `pasahero-db` with app IDs:
  - Web: `1:464857061623:web:40d74e8111583f08b85bf2`
  - Android: `1:464857061623:android:10d97a90c6aca517b85bf2`
  - iOS: `1:464857061623:ios:6107ed673c96dd72b85bf2`

**Action Required**: Update `firebase_options.dart` with the new project configuration OR re-run `flutterfire configure`

### 2. **Linter Warnings** (Non-critical)
- Dead code warnings in `auth_service.dart` (lines 148, 547)
- Null check warnings (lines 148, 149, 547, 548, 356, 698)
- These are warnings, not errors - code will still work

### 3. **Google Sign-In Client ID**
- Current: `464857061623-ohoa4afqj73bka9l3mn4rv7mdrpe0ra0.apps.googleusercontent.com`
- This is from the OLD project (`pasahero-db`)
- **If using new project**, need to get the new Web OAuth Client ID from Firebase Console

## 🔧 What Needs to Be Fixed

### Option 1: Use New Project (`pasahero-d3fff`)
1. Get the new Web OAuth Client ID from Firebase Console:
   - Go to: https://console.firebase.google.com/
   - Select project: `pasahero-d3fff`
   - Project Settings → Your apps → Web app → OAuth client ID
2. Update `firebase_options.dart` with new project details (or re-run `flutterfire configure`)
3. Update `auth_service.dart` line 32 with new Web OAuth Client ID
4. Update `index.html` line 39 with new Web OAuth Client ID
5. Download new `google-services.json` for Android

### Option 2: Keep Using Old Project (`pasahero-db`)
- Everything is already configured correctly ✅
- Just need to ensure you're using the right Firebase project

## 📋 Configuration Checklist

- [ ] `firebase_options.dart` matches the Firebase project you want to use
- [ ] `google-services.json` matches the Android app in Firebase Console
- [ ] Web OAuth Client ID in `auth_service.dart` matches Firebase Console
- [ ] Web OAuth Client ID in `index.html` matches Firebase Console
- [ ] SHA1 fingerprint added to Firebase Console for Android
- [ ] People API enabled in Google Cloud Console
- [ ] Google Sign-In enabled in Firebase Authentication

## 🎯 Next Steps

1. **Decide which project to use**: `pasahero-db` (old) or `pasahero-d3fff` (new)
2. **If using new project**: Update all configuration files
3. **If using old project**: Everything should work as-is
4. **Test Google Sign-In** on web to verify `idToken` is now returned (after setting `serverClientId`)
