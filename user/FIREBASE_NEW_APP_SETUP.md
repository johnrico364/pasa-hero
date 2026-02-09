# Firebase Console - Add New Android App with New Package Name

## ⚠️ Important Notes

1. **SHA1 is the same** - This is CORRECT! SHA1 is based on your keystore, not your package name. The same SHA1 can be used for multiple package names.

2. **You need to ADD a NEW app** - You cannot edit the package name of an existing app in Firebase. You must add a new Android app.

## Step-by-Step Instructions

### Step 1: Add New Android App in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **pasaherodb**
3. Click the ⚙️ **gear icon** next to "Project Overview"
4. Click **"Project Settings"**
5. Scroll down to the **"Your apps"** section
6. You'll see your existing Android app with `com.example.user`
7. Click the **"Add app"** button (or the **+** icon)
8. Select **Android** (the Android icon)
9. In the registration form:
   - **Android package name**: Enter `com.pasahero.app`
   - **App nickname** (optional): You can name it "PasaHero App" or leave blank
   - **Debug signing certificate SHA-1** (optional for now): Leave blank or add later
10. Click **"Register app"**

### Step 2: Download the New google-services.json

1. After registering, you'll see a screen with instructions
2. Click **"Download google-services.json"**
3. **Replace** the file at `user/android/app/google-services.json` with the downloaded file
4. The new file will have the correct `mobilesdk_app_id` for `com.pasahero.app`

### Step 3: Add SHA1 Fingerprint

1. Still in Firebase Console, in the new app's settings
2. Scroll to **"SHA certificate fingerprints"** section
3. Click **"Add fingerprint"**
4. Paste your SHA1: `F6:47:B2:87:5E:11:AD:46:F5:69:23:9A:B3:7A:81:A5:D0:F1:E3:B5`
5. Click **"Save"**

### Step 4: Update Google Cloud Console OAuth Client

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: **pasaherodb**
3. Go to **APIs & Services** → **Credentials**
4. Find your **OAuth 2.0 Client IDs**
5. You have two options:

   **Option A: Create a new Android OAuth client**
   - Click **"+ CREATE CREDENTIALS"** → **"OAuth client ID"**
   - Application type: **Android**
   - Name: "PasaHero Android" (or any name)
   - Package name: `com.pasahero.app`
   - SHA-1 certificate fingerprint: `F6:47:B2:87:5E:11:AD:46:F5:69:23:9A:B3:7A:81:A5:D0:F1:E3:B5`
   - Click **"Create"**

   **Option B: Edit existing Android OAuth client**
   - Find the existing Android OAuth client
   - Click **Edit** (pencil icon)
   - Update **Package name** to: `com.pasahero.app`
   - Update **SHA-1 certificate fingerprint** to: `F6:47:B2:87:5E:11:AD:46:F5:69:23:9A:B3:7A:81:A5:D0:F1:E3:B5`
   - Click **"Save"**

### Step 5: Verify the New google-services.json

After downloading the new file, it should have:
- `"package_name": "com.pasahero.app"` ✅
- A new `mobilesdk_app_id` that matches your new Firebase app ✅

### Step 6: Clean and Rebuild

```bash
cd user
flutter clean
flutter pub get
flutter run
```

## Summary

- ✅ SHA1 stays the same (this is normal - it's keystore-based)
- ✅ Add NEW Android app in Firebase Console (don't edit the old one)
- ✅ Download new google-services.json
- ✅ Add SHA1 to the new app in Firebase
- ✅ Update/create OAuth client in Google Cloud Console

## Why SHA1 is the Same?

The SHA1 fingerprint is generated from your **keystore file** (`~/.android/debug.keystore`), not from your package name. The same keystore can be used for multiple package names, so the SHA1 remains the same. This is completely normal and expected behavior.
