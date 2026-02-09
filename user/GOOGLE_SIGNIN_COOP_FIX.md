# Fixing Cross-Origin-Opener-Policy (COOP) for Google Sign-In

## The Problem

The error "Cross-Origin-Opener-Policy policy would block the window.closed call" occurs because the browser's security policy is blocking the popup window from communicating with the parent window.

## Solutions

### Option 1: Configure Server Headers (Recommended for Production)

If you're hosting your Flutter web app on a server, you need to set the HTTP header:

```
Cross-Origin-Opener-Policy: same-origin-allow-popups
```

#### For Apache (.htaccess):
```apache
<IfModule mod_headers.c>
  Header set Cross-Origin-Opener-Policy "same-origin-allow-popups"
</IfModule>
```

#### For Nginx:
```nginx
add_header Cross-Origin-Opener-Policy "same-origin-allow-popups";
```

#### For Netlify (netlify.toml):
```toml
[[headers]]
  for = "/*"
  [headers.values]
    Cross-Origin-Opener-Policy = "same-origin-allow-popups"
```

#### For Vercel (vercel.json):
```json
{
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        {
          "key": "Cross-Origin-Opener-Policy",
          "value": "same-origin-allow-popups"
        }
      ]
    }
  ]
}
```

### Option 2: Enable People API (For 403 Errors)

If you're seeing 403 errors when accessing the People API:

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project: **pasahero-db**
3. Go to **APIs & Services** → **Library**
4. Search for "People API"
5. Click on "Google People API"
6. Click **Enable**

**Note:** Firebase Auth doesn't actually require the People API - it uses the idToken directly. The 403 error is from the google_sign_in package trying to fetch additional user info, but Firebase Auth should still work.

### Option 3: Development Workaround

For local development with `flutter run -d chrome`, the COOP warning is expected but shouldn't prevent sign-in from working. The token retrieval should still succeed despite the warning.

## Testing

After configuring the headers:

1. Rebuild your web app: `flutter build web`
2. Deploy to your server with the headers configured
3. Test Google Sign-In - it should work without COOP warnings

## Current Status

- ✅ Token retrieval works (despite COOP warnings)
- ✅ Error handling improved for 403 errors
- ⚠️ COOP warnings will persist until server headers are configured
- ⚠️ People API 403 is informational - Firebase Auth should still work
