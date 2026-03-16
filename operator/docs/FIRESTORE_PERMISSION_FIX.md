# Firestore Permission Fix for Operator Demo Account

## Problem
When logging in with the operator demo account, you may encounter the error:
> "The caller does not have permission to execute the command"

This happens because Firestore security rules were blocking write operations.

## Solution

### 1. Updated Firestore Security Rules
The rules in `user/firestore.rules` have been updated to explicitly allow:
- **Create**: Authenticated users can create their own user document
- **Update**: Authenticated users can update their own user document
- **Read**: Authenticated users can read their own user document
- **Delete**: Authenticated users can delete their own user document

### 2. Improved Error Handling
The operator login code now:
- Uses `set()` for new documents and `update()` for existing documents (better permission handling)
- Catches `FirebaseException` with helpful error messages
- Provides clear instructions when permission errors occur

## Deploying the Rules

**Important:** You must deploy the updated Firestore rules for the fix to work!

### Option 1: Using Firebase CLI (Recommended)
```bash
cd user
firebase deploy --only firestore:rules
```

### Option 2: Using Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **pasahero-db**
3. Go to **Firestore Database** → **Rules** tab
4. Copy the contents of `user/firestore.rules`
5. Paste into the rules editor
6. Click **Publish**

## Updated Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection - authenticated users can read/write their own data
    match /users/{userId} {
      // Allow read if user is authenticated and accessing their own document
      allow read: if request.auth != null && request.auth.uid == userId;
      // Allow create if user is authenticated (for new account creation)
      allow create: if request.auth != null && request.auth.uid == userId;
      // Allow update if user is authenticated and updating their own document
      allow update: if request.auth != null && request.auth.uid == userId;
      // Allow delete if user is authenticated and deleting their own document
      allow delete: if request.auth != null && request.auth.uid == userId;
    }
    
    // OTP verifications - allow anyone to create/read (for email verification before account creation)
    match /otp_verifications/{email} {
      allow read: if true;
      allow create: if true;
      allow update: if true;
      allow delete: if true;
    }
    
    // Default deny all other access
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

## Testing
After deploying the rules:
1. Open the operator app
2. Tap "Use demo account" to create the demo account
3. Tap "Log in" with the demo credentials
4. You should now be able to log in without permission errors

## Troubleshooting

### Still getting permission errors?
1. **Verify rules are deployed**: Check Firebase Console → Firestore → Rules
2. **Check authentication**: Make sure the user is authenticated before writing to Firestore
3. **Check document ID**: The document ID must match the authenticated user's UID
4. **Check Firebase project**: Ensure both user and operator apps use the same Firebase project (`pasahero-db`)

### Rules not deploying?
- Make sure you're in the `user` directory when running `firebase deploy`
- Ensure you're logged in: `firebase login`
- Check that `firebase.json` in the `user` directory points to `firestore.rules`
