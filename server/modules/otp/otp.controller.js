import { OtpService } from './otp.service.js';
import nodemailer from 'nodemailer';

export const sendOtp = async (req, res) => {
  try {
    // Validate request body exists
    if (!req.body || typeof req.body !== 'object') {
      return res.status(400).json({ 
        success: false,
        error: 'Invalid request body',
        message: 'Request body must be a valid JSON object'
      });
    }

    const { email, otpCode } = req.body;
    
    // Validate input presence
    if (!email || !otpCode) {
      return res.status(400).json({ 
        success: false,
        error: 'Email and OTP code are required',
        received: {
          email: !!email,
          otpCode: !!otpCode
        }
      });
    }

    // Log request details (without sensitive data)
    console.log(`📨 OTP send request received`);
    console.log(`   Email: ${email.substring(0, 3)}***${email.substring(email.indexOf('@'))}`);
    console.log(`   OTP Length: ${String(otpCode).length} digits`);

    const result = await OtpService.sendOtpEmail(email, otpCode);
    
    res.json({ 
      success: true, 
      message: result.message 
    });
  } catch (error) {
    console.error('❌ Error sending OTP email:', error);
    console.error('   Error details:', {
      message: error.message,
      code: error.code,
      responseCode: error.responseCode,
      stack: error.stack
    });

    // Handle specific error types
    if (error.message === 'Email and OTP code are required') {
      return res.status(400).json({ 
        success: false,
        error: error.message 
      });
    }

    // Invalid email format
    if (error.message.includes('Invalid email format') || error.message.includes('Invalid email address format')) {
      return res.status(400).json({
        success: false,
        error: 'Invalid email format',
        message: error.message,
        troubleshooting: [
          'Ensure the email address is in the correct format (e.g., user@example.com)',
          'Check for typos in the email address',
          'Remove any extra spaces or special characters'
        ]
      });
    }

    // Invalid OTP format
    if (error.message.includes('Invalid OTP format')) {
      return res.status(400).json({
        success: false,
        error: 'Invalid OTP format',
        message: error.message,
        troubleshooting: [
          'OTP must be 4-8 digits only',
          'Do not include spaces or special characters',
          'Ensure OTP is numeric'
        ]
      });
    }

    // Email too long
    if (error.message.includes('too long')) {
      return res.status(400).json({
        success: false,
        error: 'Email address too long',
        message: error.message
      });
    }

    // Invalid EMAIL_USER configuration
    if (error.message.includes('Invalid EMAIL_USER format') || error.message.includes('Email configuration errors')) {
      return res.status(500).json({
        success: false,
        error: 'Server email configuration error',
        message: error.message,
        troubleshooting: [
          'Check EMAIL_USER in server .env file',
          'Ensure EMAIL_USER is a valid email address',
          'Check EMAIL_APP_PASSWORD is set correctly (no spaces)',
          'Restart the server after fixing the configuration'
        ]
      });
    }
    
    if (error.message.includes('Email service not configured')) {
      return res.status(503).json({
        success: false,
        error: 'Email service not configured',
        message: error.message,
        troubleshooting: 'Please configure EMAIL_USER and EMAIL_APP_PASSWORD in the server .env file'
      });
    }

    // Authentication errors (most common with Gmail)
    if (error.message.includes('authentication failed') || error.code === 'EAUTH') {
      return res.status(401).json({
        success: false,
        error: 'Email authentication failed',
        message: error.message,
        troubleshooting: [
          'Verify EMAIL_USER is your full Gmail address',
          'Verify EMAIL_APP_PASSWORD is a valid 16-character App Password (not your regular password)',
          'Ensure 2-Step Verification is enabled on your Gmail account',
          'Generate a new App Password at: https://myaccount.google.com/apppasswords'
        ]
      });
    }

    // Connection errors
    if (error.message.includes('connection failed') || error.code === 'ETIMEDOUT' || error.code === 'ECONNREFUSED') {
      return res.status(503).json({
        success: false,
        error: 'Email server connection failed',
        message: error.message,
        troubleshooting: [
          'Check your internet connection',
          'Verify Gmail SMTP servers are accessible',
          'Check if firewall is blocking the connection'
        ]
      });
    }

    // Invalid email address
    if (error.message.includes('Invalid email address') || error.code === 'EENVELOPE') {
      return res.status(400).json({
        success: false,
        error: 'Invalid email address',
        message: error.message
      });
    }

    // Generic error
    res.status(500).json({ 
      success: false,
      error: 'Failed to send OTP email', 
      message: error.message,
      errorCode: error.code || 'UNKNOWN'
    });
  }
};

// Server connectivity check endpoint
export const checkServerStatus = async (req, res) => {
  try {
    const serverPort = process.env.PORT || 3000;
    const serverInfo = {
      status: 'online',
      port: serverPort,
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      environment: process.env.NODE_ENV || 'development',
    };

    // Check if email service is configured
    const emailConfigured = !!(process.env.EMAIL_USER && process.env.EMAIL_APP_PASSWORD);
    
    res.json({
      success: true,
      message: 'Server is online and accessible',
      server: serverInfo,
      services: {
        email: {
          configured: emailConfigured,
          user: emailConfigured ? process.env.EMAIL_USER.substring(0, 3) + '***' : 'Not configured',
        },
      },
      endpoints: {
        health: '/health',
        otpSend: '/api/otp/send',
        otpTestConfig: '/api/otp/test-config',
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: 'Server status check failed',
      message: error.message,
    });
  }
};

// Test email configuration endpoint (for debugging)
export const testEmailConfig = async (req, res) => {
  try {
    // Check if email credentials are configured
    if (!process.env.EMAIL_USER || !process.env.EMAIL_APP_PASSWORD) {
      return res.status(503).json({
        success: false,
        error: 'Email credentials not configured',
        message: 'EMAIL_USER and EMAIL_APP_PASSWORD must be set in .env file',
        configured: {
          EMAIL_USER: !!process.env.EMAIL_USER,
          EMAIL_APP_PASSWORD: !!process.env.EMAIL_APP_PASSWORD,
          EMAIL_FROM: process.env.EMAIL_FROM || 'Not set',
        }
      });
    }

    // Create transporter
    let transporter;
    if (process.env.SMTP_HOST) {
      transporter = nodemailer.createTransport({
        host: process.env.SMTP_HOST,
        port: parseInt(process.env.SMTP_PORT || '587'),
        secure: process.env.SMTP_SECURE === 'true',
        auth: {
          user: process.env.EMAIL_USER,
          pass: process.env.EMAIL_APP_PASSWORD || process.env.SMTP_PASSWORD,
        },
      });
    } else {
      transporter = nodemailer.createTransport({
        service: 'gmail',
        auth: {
          user: process.env.EMAIL_USER,
          pass: process.env.EMAIL_APP_PASSWORD,
        },
      });
    }

    // Test connection
    await transporter.verify();
    
    res.json({
      success: true,
      message: 'Email configuration is valid',
      configuration: {
        emailUser: process.env.EMAIL_USER,
        emailFrom: process.env.EMAIL_FROM || `PasaHero <${process.env.EMAIL_USER}>`,
        smtpHost: process.env.SMTP_HOST || 'gmail (default)',
        smtpPort: process.env.SMTP_PORT || '587 (default)',
      }
    });
  } catch (error) {
    console.error('Email configuration test failed:', error);
    res.status(500).json({
      success: false,
      error: 'Email configuration test failed',
      message: error.message,
      errorCode: error.code,
      troubleshooting: error.code === 'EAUTH' 
        ? 'Check EMAIL_USER and EMAIL_APP_PASSWORD. Ensure you are using a Gmail App Password, not your regular password.'
        : 'Check your email configuration in the .env file and ensure internet connection is working.'
    });
  }
};
