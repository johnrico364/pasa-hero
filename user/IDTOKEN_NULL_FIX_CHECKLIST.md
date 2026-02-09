# Complete Checklist: Why idToken is Null

Since you've enabled People API but idToken is still null, here's a comprehensive checklist to verify everything:

## ✅ Step 1: Verify People API is Actually Enabled

1. Go to: https://console.cloud.google.com/
2. Select project: **pasahero-db**
3. Click **"APIs & Services"** → **"Enabled APIs"**
4. Search for: **"People API"**
5. **VERIFY**: You should see **"Google People API"** with a green checkmark
6. If it's NOT there, go to **"Library"** → Search **"People API"** → Click **"Enable"**
7. **Wait 2-3 minutes** after enabling

## ✅ Step 2: Check OAuth Client Configuration

1. Go to: https://console.cloud.google.com/
2. Select project: **pasahero-db**
3. Click **"APIs & Services"** → **"Credentials"**
4. Find your **Web OAuth Client ID**: `464857061623-ohoa4afqj73bka9l3mn4rv7mdrpe0ra0`
5. Click on it to edit
6. **VERIFY**:
   - **Authorized JavaScript origins** includes your domain (e.g., `http://localhost:xxxx` or your production domain)
   - **Authorized redirect URIs** is configured (can be empty for web, but should match if set)
   - **Application type** is "Web application"

## ✅ Step 3: Check OAuth Consent Screen

1. Go to: https://console.cloud.google.com/
2. Select project: **pasahero-db**
3. Click **"APIs & Services"** → **"OAuth consent screen"**
4. **VERIFY**:
   - **User Type** is set (Internal or External)
   - **Scopes** include:
     - `email`
     - `profile`
     - `openid`
     - `https://www.googleapis.com/auth/userinfo.email`
     - `https://www.googleapis.com/auth/userinfo.profile`
   - **Test users** (if Internal) includes your Google account

## ✅ Step 4: Verify Firebase Configuration

1. Go to: https://console.firebase.google.com/
2. Select project: **pasahero-db**
3. Click ⚙️ → **Project Settings**
4. Go to **"Your apps"** → Find your **Web app**
5. **VERIFY**:
   - **OAuth client ID** matches: `464857061623-ohoa4afqj73bka9l3mn4rv7mdrpe0ra0`
   - **Google Sign-In** is enabled in **Authentication** → **Sign-in method**

## ✅ Step 5: Check Browser Settings

1. **Enable third-party cookies** in your browser
2. **Clear browser cache** and cookies for your domain
3. **Try in incognito/private mode** to rule out extensions
4. **Try a different browser** (Chrome, Firefox, Edge)

## ✅ Step 6: Verify Code Configuration

Check that your code has:
- ✅ `scopes: ['email', 'profile', 'openid']` in GoogleSignIn initialization
- ✅ Client ID in `index.html`: `464857061623-ohoa4afqj73bka9l3mn4rv7mdrpe0ra0`
- ✅ `serverClientId: null` for web (to avoid assertion errors)

## 🔍 The Real Issue

The `google_sign_in` package on web has a **known limitation**: it doesn't always return `idToken` even with proper configuration. This is because:

1. The package uses authorization code flow which doesn't return `id_token` directly
2. The `id_token` should be obtained when exchanging the code, but the package may not do this properly on web
3. People API being enabled helps, but doesn't guarantee `idToken` will be returned

## 💡 Alternative Solution

If People API is enabled and idToken is still null, you may need to:
1. Wait longer (5-10 minutes) for People API to fully propagate
2. Clear all browser data and try again
3. Check if there are any errors in Google Cloud Console logs
4. Consider using a different authentication method for web

## 📋 What to Check Next

After verifying all the above:
1. **Clear browser cache completely**
2. **Wait 5-10 minutes** after enabling People API
3. **Try signing in again**
4. **Check the console logs** - you should see the detailed debug output
5. **Check Google Cloud Console** → **APIs & Services** → **Enabled APIs** to confirm People API is there

If idToken is STILL null after all this, it's likely a limitation of the `google_sign_in` package on web, and you may need to use a different approach or wait for a package update.
