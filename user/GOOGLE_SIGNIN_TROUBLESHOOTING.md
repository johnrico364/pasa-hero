# Google Sign-In Troubleshooting Guide

## Current Issue: User Not Saved to Firestore

When you click on your Google account, the popup closes but the account is not saved in Firebase.

## Debug Steps

### 1. Check Browser Console Logs

Open your browser's Developer Tools (F12) and go to the Console tab. Look for these messages when you try to sign up:

**Expected Flow:**
```
🔑 Requesting authentication from Google...
✅ Authentication retrieved successfully (or after retry)
✅ idToken retrieved successfully
✅ Google authentication successful, signing in to Firebase...
✅ Firebase sign-in successful, user ID: [user-id]
🔍 Checking if user exists in Firestore...
📝 Creating new user in Firestore...
📝 Writing user data to Firestore: {...}
✅ User created successfully in Firestore with ID: [user-id]
✅ Verified: User document exists in Firestore
✅ Google Sign-Up completed successfully
```

**If you see errors:**
- `⚠️ Authentication call error` - People API issue (usually not blocking)
- `❌ Error creating user in Firestore` - Firestore write failed (this is the problem!)
- `❌ idToken is null` - Token retrieval failed

### 2. Check Firestore Rules

The most common issue is Firestore security rules blocking the write. Check your Firestore rules:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **pasahero-db**
3. Go to **Firestore Database** → **Rules**
4. Make sure you have rules that allow authenticated users to write:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      // Allow authenticated users to create/update their own user document
      allow read, write: if request.auth != null && request.auth.uid == userId;
      // Allow users to create their own document during sign-up
      allow create: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### 3. Enable People API (Optional but Recommended)

The 403 error on People API won't block sign-in, but enabling it will reduce errors:

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: **pasahero-db**
3. Go to **APIs & Services** → **Library**
4. Search for "People API"
5. Click **Enable**

### 4. Check Network Tab

In Developer Tools, go to the **Network** tab and look for:
- Failed requests to `firestore.googleapis.com`
- Check the response status codes (should be 200, not 403 or 401)

### 5. Verify Firebase Authentication

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **pasahero-db**
3. Go to **Authentication** → **Users**
4. Check if the user appears here (even if not in Firestore)

If the user appears in Authentication but not in Firestore, it means:
- ✅ Google Sign-In worked
- ✅ Firebase Auth worked
- ❌ Firestore write failed (check rules and network)

## Common Solutions

### Solution 1: Fix Firestore Rules
Update your Firestore rules to allow user creation (see step 2 above).

### Solution 2: Check Firestore Permissions
Make sure your Firebase project has Firestore enabled and properly configured.

### Solution 3: Check Network Connectivity
Ensure there are no network issues blocking Firestore writes.

### Solution 4: Check Error Messages
Look at the console logs - the new logging will tell you exactly where it's failing.

## What the Code Does Now

1. **Improved Error Handling**: Better retry logic for People API errors
2. **Detailed Logging**: Every step is logged so you can see exactly where it fails
3. **Error Throwing**: If Firestore write fails, an error is thrown and displayed to the user
4. **Verification**: After creating the user, it verifies the document exists

## Next Steps

1. Try signing up again
2. Check the browser console for the log messages
3. Share the console output if it's still not working
4. Check Firestore rules as described above

The detailed logging will help identify the exact point of failure.
