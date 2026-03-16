# Operator Registration Troubleshooting Guide

## Common Issues and Solutions

### Issue: "Cannot create account" or "Permission denied"

This usually means **Firestore security rules are not deployed**.

## Quick Fix

### Step 1: Deploy Firestore Rules

Open a terminal and run:

```bash
cd user
firebase deploy --only firestore:rules
```

**OR** manually update in Firebase Console:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: **pasahero-db**
3. Go to **Firestore Database** → **Rules** tab
4. Copy the contents from `user/firestore.rules` file
5. Paste into the rules editor
6. Click **Publish**

### Step 2: Verify Rules Are Deployed

After deploying, the rules should look like this:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow create: if request.auth != null && request.auth.uid == userId;
      allow update: if request.auth != null && request.auth.uid == userId;
      allow delete: if request.auth != null && request.auth.uid == userId;
    }
    
    match /otp_verifications/{email} {
      allow read: if true;
      allow create: if true;
      allow update: if true;
      allow delete: if true;
    }
    
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

### Step 3: Try Registration Again

After deploying rules, try registering again.

## Other Common Issues

### "Email already registered" but login fails

This means the account exists in Firebase Auth but not in Firestore (orphaned account).

**Solution:**
1. Try registering again with the same email and password
2. The app will automatically recover the account
3. If password is wrong, you'll need to reset it

### "Firestore unavailable" or "Request timeout"

**Solution:**
- Check your internet connection
- Wait a few minutes and try again
- Check Firebase status: https://status.firebase.google.com/

### "Firebase not initialized"

**Solution:**
- Restart the app
- Make sure `google-services.json` (Android) or `GoogleService-Info.plist` (iOS) is in place
- Check that Firebase is properly configured in `firebase_options.dart`

## Still Having Issues?

1. **Check the console logs** - Look for error messages starting with `❌ [LoginForm]`
2. **Verify Firebase project** - Make sure operator app uses `pasahero-db` project
3. **Check authentication** - Make sure you're logged into Firebase CLI: `firebase login`
4. **Test Firestore connection** - Try accessing Firestore in Firebase Console to verify it's working

## Need More Help?

Check the error message in the app - it should tell you exactly what's wrong and how to fix it.
