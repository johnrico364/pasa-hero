# ⚠️ CRITICAL: You MUST Enable People API

## The Problem

You're getting this error:
```
Google Sign-Up failed: ClientException: { "error": {
GET https://content-people.googleapis.com/v1/people/me?... 403 (Forbidden)
```

**This means People API is NOT enabled in your Google Cloud Console.**

## Why This Happens

The `google_sign_in` package tries to:
1. ✅ Get OAuth tokens (this works - you can see the access_token in console)
2. ❌ Fetch user profile from People API (this FAILS with 403)
3. ❌ Return authentication object (this FAILS because step 2 failed)

**Even though the tokens are available, the exception prevents us from accessing them.**

## The Solution (REQUIRED - No Workaround)

You **MUST** enable People API. There is **NO code fix** for this. It's a Google Cloud Console configuration.

### Step-by-Step Instructions:

1. **Open Google Cloud Console**
   - Go to: https://console.cloud.google.com/
   - Make sure you're logged in with the correct Google account

2. **Select Your Project**
   - At the top, click the project dropdown
   - Select: **pasahero-db**
   - If you don't see it, make sure you have access to it

3. **Navigate to APIs & Services**
   - In the left sidebar, click **"APIs & Services"**
   - Then click **"Library"**

4. **Search for People API**
   - In the search bar at the top, type: **"People API"**
   - Press Enter or click the search icon

5. **Select Google People API**
   - Click on **"Google People API"** from the search results
   - (It should show a description about accessing profile information)

6. **Enable the API**
   - Click the big blue **"ENABLE"** button
   - Wait for it to enable (usually 10-30 seconds)
   - You should see "API enabled" with a green checkmark

7. **Verify It's Enabled**
   - The button should now say **"MANAGE"** instead of "ENABLE"
   - You should see a green checkmark or "API enabled" message

8. **Wait 1-2 Minutes**
   - The API needs a moment to fully activate
   - Don't try to sign in immediately

9. **Try Again**
   - Refresh your web app page
   - Try Google Sign-In again
   - It should work now!

## How to Verify People API is Enabled

1. Go to **APIs & Services** → **Enabled APIs**
2. Search for "People API"
3. You should see **"Google People API"** in the list
4. If it's not there, it's not enabled - go back and enable it

## Common Issues

### "I can't find the project"
- Make sure you're logged in with the correct Google account
- Check if you have access to the project
- The project name is: **pasahero-db**

### "I enabled it but it still doesn't work"
- Wait 2-3 minutes after enabling
- Make sure you clicked "ENABLE" (not just viewed the page)
- Check "Enabled APIs" to verify it's actually enabled
- Try refreshing your web app page
- Clear browser cache if needed

### "I don't have access to Google Cloud Console"
- You need to be a project owner or have API management permissions
- Contact your project administrator

## Why This Is Required

Google Sign-In on web **requires** People API to be enabled. This is a Google requirement, not something we can work around in code.

The `google_sign_in` package's `authentication` property internally calls People API to fetch user profile information. When People API is not enabled, it returns a 403 Forbidden error, which causes the entire authentication call to fail.

## After Enabling

Once People API is enabled:
- ✅ The 403 error will disappear
- ✅ Google Sign-In will work properly
- ✅ Users will be able to sign in and sign up
- ✅ User data will be saved to Firestore

---

**This is the ONLY solution. Please enable People API now.**
