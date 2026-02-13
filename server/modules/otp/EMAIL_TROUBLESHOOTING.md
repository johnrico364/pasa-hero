# Email OTP Troubleshooting Guide

## Common Issues and Solutions

### 1. "Email service not configured" Error

**Problem:** `EMAIL_USER` or `EMAIL_APP_PASSWORD` is not set in the `.env` file.

**Solution:**
1. Create a `.env` file in the `server/` directory (copy from `env.example`)
2. Add the following variables:
   ```
   EMAIL_USER=your-email@gmail.com
   EMAIL_APP_PASSWORD=your-16-char-app-password
   EMAIL_FROM=PasaHero <your-email@gmail.com>
   ```
3. Restart the server after adding the variables

---

### 2. "Email authentication failed" Error (EAUTH)

**Problem:** Gmail authentication is failing. This is the most common issue.

**Solutions:**

#### A. Use Gmail App Password (Required)
Gmail no longer supports "Less secure app access". You MUST use an App Password:

1. **Enable 2-Step Verification:**
   - Go to: https://myaccount.google.com/security
   - Enable "2-Step Verification" if not already enabled

2. **Generate App Password:**
   - Go to: https://myaccount.google.com/apppasswords
   - Select "Mail" as the app
   - Select "Other (Custom name)" as the device
   - Enter "PasaHero Server" as the name
   - Click "Generate"
   - Copy the 16-character password (no spaces)

3. **Update .env file:**
   ```
   EMAIL_USER=your-email@gmail.com
   EMAIL_APP_PASSWORD=xxxx xxxx xxxx xxxx  (16 characters, remove spaces)
   ```

4. **Important:** 
   - Use the App Password, NOT your regular Gmail password
   - The App Password should be exactly 16 characters (remove any spaces)
   - If you regenerate the App Password, update the `.env` file

#### B. Verify Email Format
- `EMAIL_USER` should be your full Gmail address: `yourname@gmail.com`
- Not just `yourname` or `yourname@`

#### C. Check for Typos
- Double-check the App Password in `.env` file
- Make sure there are no extra spaces or newlines
- Restart the server after making changes

---

### 3. "Email server connection failed" Error

**Problem:** Cannot connect to Gmail SMTP servers.

**Solutions:**
1. **Check Internet Connection:**
   - Ensure the server has internet access
   - Test: `ping smtp.gmail.com`

2. **Check Firewall:**
   - Ensure port 587 (SMTP) is not blocked
   - Check if corporate firewall is blocking SMTP

3. **Check Gmail Status:**
   - Visit: https://www.google.com/appsstatus
   - Ensure Gmail is operational

---

### 4. Emails Not Reaching Recipients

**Problem:** Email is sent successfully but recipient doesn't receive it.

**Solutions:**

#### A. Check Spam Folder
- Gmail may mark automated emails as spam
- Ask users to check their Spam/Junk folder

#### B. Check Gmail Sending Limits
- Gmail has daily sending limits (500 emails/day for free accounts)
- If exceeded, emails will be rejected

#### C. Verify Recipient Email
- Ensure the recipient email address is correct
- Test with your own email first

#### D. Check Email Logs
- Check server console for error messages
- Look for "Message ID" in success logs

---

### 5. Testing Email Configuration

**Test the email configuration:**

1. **Check if transporter verifies:**
   - Start the server
   - Look for: `✅ Email transporter verified successfully`
   - If you see: `❌ Email transporter verification failed`, check the error message

2. **Test sending:**
   - Try sending an OTP to your own email
   - Check server logs for detailed error messages
   - Check your email inbox (and spam folder)

3. **Use the test endpoint (if available):**
   ```bash
   curl -X POST http://localhost:3000/api/otp/send \
     -H "Content-Type: application/json" \
     -d '{"email":"your-email@gmail.com","otpCode":"123456"}'
   ```

---

### 6. Alternative: Use Custom SMTP

If Gmail continues to cause issues, you can use a custom SMTP provider:

**In `.env` file:**
```
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_SECURE=false
EMAIL_USER=your-email@gmail.com
EMAIL_APP_PASSWORD=your-app-password
```

Or use other providers:
- **Outlook:** `SMTP_HOST=smtp-mail.outlook.com`, `SMTP_PORT=587`
- **Yahoo:** `SMTP_HOST=smtp.mail.yahoo.com`, `SMTP_PORT=587`
- **SendGrid:** `SMTP_HOST=smtp.sendgrid.net`, `SMTP_PORT=587`

---

## Quick Checklist

Before reporting an issue, verify:

- [ ] `.env` file exists in `server/` directory
- [ ] `EMAIL_USER` is set to full Gmail address
- [ ] `EMAIL_APP_PASSWORD` is set (16 characters, no spaces)
- [ ] 2-Step Verification is enabled on Gmail account
- [ ] App Password was generated (not regular password)
- [ ] Server was restarted after changing `.env` file
- [ ] Internet connection is working
- [ ] Checked server console for error messages
- [ ] Tested with your own email address first

---

## Getting Help

If issues persist:

1. **Check server logs** for detailed error messages
2. **Test with your own email** first
3. **Verify App Password** is correct by generating a new one
4. **Check Gmail account** for any security alerts or blocks
5. **Review error messages** - they now include specific troubleshooting steps

---

## Example .env Configuration

```env
# Server Configuration
PORT=3000

# Email Configuration (Gmail with App Password)
EMAIL_USER=yourname@gmail.com
EMAIL_APP_PASSWORD=abcd efgh ijkl mnop
EMAIL_FROM=PasaHero <yourname@gmail.com>

# Optional: Custom SMTP (uncomment to use)
# SMTP_HOST=smtp.gmail.com
# SMTP_PORT=587
# SMTP_SECURE=false
```

**Note:** Remove spaces from App Password when pasting into `.env` file.
