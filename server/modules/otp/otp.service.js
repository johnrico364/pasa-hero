import nodemailer from 'nodemailer';

// Email validation regex
const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
// OTP validation - should be 4-8 digits
const OTP_REGEX = /^\d{4,8}$/;

/**
 * Validate email configuration
 * @throws {Error} If configuration is invalid
 */
function validateEmailConfiguration() {
  const errors = [];

  if (!process.env.EMAIL_USER) {
    errors.push('EMAIL_USER is not set');
  } else if (!EMAIL_REGEX.test(process.env.EMAIL_USER)) {
    errors.push(`EMAIL_USER has invalid format: ${process.env.EMAIL_USER}`);
  }

  if (!process.env.EMAIL_APP_PASSWORD) {
    errors.push('EMAIL_APP_PASSWORD is not set');
  } else {
    const appPassword = String(process.env.EMAIL_APP_PASSWORD).trim();
    if (appPassword.length < 8) {
      errors.push('EMAIL_APP_PASSWORD is too short (minimum 8 characters)');
    }
    if (appPassword.includes(' ')) {
      errors.push('EMAIL_APP_PASSWORD contains spaces (remove all spaces)');
    }
  }

  if (errors.length > 0) {
    throw new Error(
      `Email configuration errors:\n${errors.map((e, i) => `${i + 1}. ${e}`).join('\n')}\n\n` +
      'Please check your .env file configuration.'
    );
  }
}

export const OtpService = {
  // SEND OTP EMAIL ===================================================================
  async sendOtpEmail(email, otpCode) {
    // Validate input presence
    if (!email || !otpCode) {
      throw new Error('Email and OTP code are required');
    }

    // Trim and validate email format
    const trimmedEmail = email.trim().toLowerCase();
    if (!trimmedEmail) {
      throw new Error('Email address cannot be empty');
    }

    if (!EMAIL_REGEX.test(trimmedEmail)) {
      throw new Error(`Invalid email format: ${email}. Please provide a valid email address.`);
    }

    // Validate email length (RFC 5321 limit is 320 characters)
    if (trimmedEmail.length > 320) {
      throw new Error('Email address is too long (maximum 320 characters)');
    }

    // Validate OTP code format
    const trimmedOtp = String(otpCode).trim();
    if (!trimmedOtp) {
      throw new Error('OTP code cannot be empty');
    }

    if (!OTP_REGEX.test(trimmedOtp)) {
      throw new Error(`Invalid OTP format: ${otpCode}. OTP must be 4-8 digits.`);
    }

    // Validate email configuration
    try {
      validateEmailConfiguration();
    } catch (configError) {
      console.error('❌ Email configuration validation failed:', configError.message);
      throw new Error(
        'Email service not configured correctly. ' + configError.message
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
        // Add connection timeout and retry options
        connectionTimeout: 10000, // 10 seconds
        greetingTimeout: 5000, // 5 seconds
        socketTimeout: 10000, // 10 seconds
      });
    } else {
      // Gmail configuration (requires App Password)
      transporter = nodemailer.createTransport({
        service: 'gmail',
        auth: {
          user: process.env.EMAIL_USER,
          pass: process.env.EMAIL_APP_PASSWORD,
        },
        // Add connection timeout and retry options for Gmail
        connectionTimeout: 10000, // 10 seconds
        greetingTimeout: 5000, // 5 seconds
        socketTimeout: 10000, // 10 seconds
      });
    }

    // Verify transporter connection before sending
    try {
      console.log(`🔍 Verifying email connection for ${process.env.EMAIL_USER}...`);
      await transporter.verify();
      console.log('✅ Email transporter verified successfully');
    } catch (verifyError) {
      console.error('❌ Email transporter verification failed:', verifyError.message);
      
      // Provide helpful error messages based on common issues
      if (verifyError.code === 'EAUTH') {
        throw new Error(
          'Email authentication failed. Please check:\n' +
          '1. EMAIL_USER is correct\n' +
          '2. EMAIL_APP_PASSWORD is a valid Gmail App Password (not your regular password)\n' +
          '3. 2-Step Verification is enabled on your Gmail account\n' +
          '4. App Password was generated correctly (16 characters, no spaces)\n' +
          `Error details: ${verifyError.message}`
        );
      } else if (verifyError.code === 'ETIMEDOUT' || verifyError.code === 'ECONNREFUSED') {
        throw new Error(
          'Email server connection failed. Please check:\n' +
          '1. Internet connection is working\n' +
          '2. Gmail SMTP servers are accessible\n' +
          '3. Firewall is not blocking the connection\n' +
          `Error details: ${verifyError.message}`
        );
      } else {
        throw new Error(
          `Email transporter verification failed: ${verifyError.message}\n` +
          'Please check your email configuration in the .env file.'
        );
      }
    }

    // Email content
    const mailOptions = {
      from: process.env.EMAIL_FROM || `PasaHero <${process.env.EMAIL_USER}>`,
      to: trimmedEmail,
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
              <h1 style="color: #1E3A8A; font-size: 36px; letter-spacing: 8px; margin: 0;">${trimmedOtp}</h1>
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
      text: `Your PasaHero verification code is: ${trimmedOtp}\n\nThis code will expire in 5 minutes.\n\nIf you didn't request this code, please ignore this email.`,
    };

    // Send email with error handling
    try {
      console.log(`📧 Attempting to send OTP email to ${trimmedEmail}...`);
      const info = await transporter.sendMail(mailOptions);
      console.log(`✅ OTP email sent successfully to ${trimmedEmail}`);
      console.log(`   Message ID: ${info.messageId}`);
      console.log(`   OTP Code: ${trimmedOtp}`);
      return { message: 'OTP email sent successfully' };
    } catch (sendError) {
      console.error('❌ Failed to send OTP email:', sendError);
      
      // Provide detailed error information
      if (sendError.code === 'EAUTH') {
        throw new Error(
          'Email authentication failed while sending. Please verify:\n' +
          '1. EMAIL_APP_PASSWORD is correct and not expired\n' +
          '2. Gmail account has 2-Step Verification enabled\n' +
          `Error: ${sendError.message}`
        );
      } else if (sendError.code === 'EENVELOPE') {
        throw new Error(
          `Invalid email address format: ${trimmedEmail}\n` +
          `Please verify the email address is correct.\n` +
          `Error: ${sendError.message}`
        );
      } else if (sendError.responseCode === 550 || sendError.responseCode === 553) {
        throw new Error(
          `Email rejected by server. The recipient email "${trimmedEmail}" may be invalid, blocked, or not accepting emails.\n` +
          `Please verify the email address is correct and active.\n` +
          `Error: ${sendError.message}`
        );
      } else {
        throw new Error(
          `Failed to send email: ${sendError.message}\n` +
          `Error code: ${sendError.code || 'UNKNOWN'}`
        );
      }
    }
  },
};
