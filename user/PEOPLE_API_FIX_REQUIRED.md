# CRITICAL FIX REQUIRED: Enable People API

## The Root Cause

The **People API 403 error is blocking Google Sign-In**. The `googleUser.authentication` call throws an exception when it tries to fetch user profile information, and this prevents the idToken from being retrieved.

**The access token is successfully retrieved**, but the **idToken cannot be accessed** because the authentication call fails.

## The Solution (REQUIRED)

You **MUST** enable the People API in Google Cloud Console. This is not optional - it's required for Google Sign-In to work on web.

### Step-by-Step Instructions:

1. **Go to Google Cloud Console**
   - Visit: https://console.cloud.google.com/

2. **Select Your Project**
   - Project: **pasahero-db**

3. **Navigate to APIs & Services**
   - Click on **"APIs & Services"** in the left sidebar
   - Click on **"Library"**

4. **Search for People API**
   - In the search bar, type: **"People API"**
   - Click on **"Google People API"** from the results

5. **Enable the API**
   - Click the **"Enable"** button
   - Wait for it to enable (usually takes a few seconds)

6. **Verify It's Enabled**
   - You should see "API enabled" with a green checkmark
   - The button should now say "Manage" instead of "Enable"

## Why This Is Required

The `google_sign_in` package's `authentication` property tries to:
1. Get the OAuth tokens (access_token, idToken) ✅ This works
2. Fetch user profile info from People API ❌ This fails with 403
3. Return the authentication object ❌ This fails because step 2 failed

Even though the tokens are available, the exception from People API prevents us from accessing them.

## After Enabling People API

1. **Wait 1-2 minutes** for the API to fully activate
2. **Try Google Sign-In again**
3. The 403 error should disappear
4. Authentication should work properly

## Alternative: Check API Status

If you're not sure if it's enabled:
1. Go to **APIs & Services** → **Enabled APIs**
2. Search for "People API"
3. If it's not listed, enable it as described above

## Why Retry Logic Doesn't Work

The retry logic we added helps with transient errors, but **People API 403 is a permanent error** until you enable the API. The package will keep throwing the exception until the API is enabled.

---

**This is the ONLY solution that will actually fix the problem.** All the code changes we made are just workarounds - the real fix is enabling People API.
