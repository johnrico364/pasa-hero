import nodemailer from 'nodemailer';

export const OtpService = {
  // SEND OTP EMAIL ===================================================================
  async sendOtpEmail(email, otpCode) {
    if (!email || !otpCode) {
      throw new Error('Email and OTP code are required');
    }

    // Check if email credentials are configured
    if (!process.env.EMAIL_USER || !process.env.EMAIL_APP_PASSWORD) {
      console.warn('⚠️  Email credentials not configured. OTP email will not be sent.');
      console.warn('   Set EMAIL_USER and EMAIL_APP_PASSWORD in .env file');
      throw new Error(
        'Email service not configured. Please configure EMAIL_USER and EMAIL_APP_PASSWORD in server .env file. See README_EMAIL_SETUP.md for instructions.'
      );
    }

    // Configure email transporter
    // Supports Gmail (with App Password) or custom SMTP
    let transporter;

    if (process.env.SMTP_HOST) {
      // Custom SMTP configuration (for other email providers)
      transporter = nodemailer.createTransport({
        host: process.env.SMTP_HOST,
        port: parseInt(process.env.SMTP_PORT || '587'),
        secure: process.env.SMTP_SECURE === 'true', // true for 465, false for other ports
        auth: {
          user: process.env.EMAIL_USER,
          pass: process.env.EMAIL_APP_PASSWORD || process.env.SMTP_PASSWORD,
        },
      });
    } else {
      // Gmail configuration (requires App Password)
      transporter = nodemailer.createTransport({
        service: 'gmail',
        auth: {
          user: process.env.EMAIL_USER,
          pass: process.env.EMAIL_APP_PASSWORD,
        },
      });
    }

    // Email content
    const mailOptions = {
      from: process.env.EMAIL_FROM || 'PasaHero <noreply@pasahero-db.firebaseapp.com>',
      to: email,
      subject: 'Your PasaHero Verification Code',
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
        </head>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
          <div style="background-color: #1E3A8A; padding: 20px; text-align: center; border-radius: 10px 10px 0 0;">
            <h1 style="color: white; margin: 0;">PasaHero</h1>
          </div>
          <div style="background-color: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px;">
            <h2 style="color: #1E3A8A; margin-top: 0;">Email Verification Code</h2>
            <p>Hello,</p>
            <p>Thank you for signing up with PasaHero! Please use the following verification code to complete your registration:</p>
            <div style="background-color: white; border: 2px solid #1E3A8A; border-radius: 8px; padding: 20px; text-align: center; margin: 20px 0;">
              <h1 style="color: #1E3A8A; font-size: 36px; letter-spacing: 8px; margin: 0;">${otpCode}</h1>
            </div>
            <p>This code will expire in 5 minutes.</p>
            <p>If you didn't request this code, please ignore this email.</p>
            <p style="margin-top: 30px; color: #666; font-size: 14px;">
              Best regards,<br>
              The PasaHero Team
            </p>
          </div>
        </body>
        </html>
      `,
      text: `Your PasaHero verification code is: ${otpCode}\n\nThis code will expire in 5 minutes.\n\nIf you didn't request this code, please ignore this email.`,
    };

    // Send email
    await transporter.sendMail(mailOptions);
    console.log(`✅ OTP email sent to ${email}`);

    return { message: 'OTP email sent successfully' };
  },
};
