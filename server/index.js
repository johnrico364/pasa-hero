const express = require('express');
const cors = require('cors');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Initialize Firebase Admin SDK
// Make sure to set GOOGLE_APPLICATION_CREDENTIALS environment variable
// or use serviceAccountKey.json file
let serviceAccount;
try {
  // Try to load from environment variable (for production)
  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
  } else {
    // Try to load from file (for local development)
    serviceAccount = require('./serviceAccountKey.json');
  }
} catch (error) {
  console.warn('⚠️  Firebase Admin SDK not initialized. Some features may not work.');
  console.warn('   To fix: Add serviceAccountKey.json or set FIREBASE_SERVICE_ACCOUNT env variable');
}

if (serviceAccount) {
  try {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: serviceAccount.project_id || 'pasaherodb',
    });
    console.log('✅ Firebase Admin SDK initialized successfully');
  } catch (error) {
    console.error('❌ Error initializing Firebase Admin SDK:', error.message);
  }
}

// Middleware
// CORS configuration - allow all localhost ports for development
const allowedOrigins = process.env.ALLOWED_ORIGINS?.split(',').map(o => o.trim()) || [
  'http://localhost:3000', 
  'http://localhost:5173',
  'http://localhost:8080',
  'http://localhost:5000',
  'http://localhost:51140', // Flutter web default port
  /^http:\/\/localhost:\d+$/, // Allow any localhost port
  'https://pasahero-db.firebaseapp.com',
  'https://pasahero-db.web.app',
];

app.use(cors({
  origin: function (origin, callback) {
    // Allow requests with no origin (like mobile apps or curl requests)
    if (!origin) return callback(null, true);
    
    // Check if origin matches any allowed origin
    const isAllowed = allowedOrigins.some(allowed => {
      if (typeof allowed === 'string') {
        return origin === allowed;
      } else if (allowed instanceof RegExp) {
        return allowed.test(origin);
      }
      return false;
    });
    
    if (isAllowed) {
      callback(null, true);
    } else {
      // In development, allow all localhost origins
      if (origin.startsWith('http://localhost:') || origin.startsWith('http://127.0.0.1:')) {
        callback(null, true);
      } else {
        callback(new Error('Not allowed by CORS'));
      }
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    firebase: admin.apps.length > 0 ? 'connected' : 'not configured',
  });
});

// API Routes
const apiRouter = express.Router();

// Get all users
apiRouter.get('/users', async (req, res) => {
  try {
    if (!admin.apps.length) {
      return res.status(503).json({ error: 'Firebase Admin not configured' });
    }

    const db = admin.firestore();
    const usersSnapshot = await db.collection('users').get();
    const users = usersSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    }));

    res.json({ success: true, data: users, count: users.length });
  } catch (error) {
    console.error('Error fetching users:', error);
    res.status(500).json({ error: 'Failed to fetch users', message: error.message });
  }
});

// Get user by ID
apiRouter.get('/users/:id', async (req, res) => {
  try {
    if (!admin.apps.length) {
      return res.status(503).json({ error: 'Firebase Admin not configured' });
    }

    const db = admin.firestore();
    const userDoc = await db.collection('users').doc(req.params.id).get();

    if (!userDoc.exists) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({ success: true, data: { id: userDoc.id, ...userDoc.data() } });
  } catch (error) {
    console.error('Error fetching user:', error);
    res.status(500).json({ error: 'Failed to fetch user', message: error.message });
  }
});

// Update user
apiRouter.put('/users/:id', async (req, res) => {
  try {
    if (!admin.apps.length) {
      return res.status(503).json({ error: 'Firebase Admin not configured' });
    }

    const db = admin.firestore();
    const { id, ...updateData } = req.body;

    await db.collection('users').doc(req.params.id).update({
      ...updateData,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    res.json({ success: true, message: 'User updated successfully' });
  } catch (error) {
    console.error('Error updating user:', error);
    res.status(500).json({ error: 'Failed to update user', message: error.message });
  }
});

// Delete user
apiRouter.delete('/users/:id', async (req, res) => {
  try {
    if (!admin.apps.length) {
      return res.status(503).json({ error: 'Firebase Admin not configured' });
    }

    const db = admin.firestore();
    await db.collection('users').doc(req.params.id).delete();

    res.json({ success: true, message: 'User deleted successfully' });
  } catch (error) {
    console.error('Error deleting user:', error);
    res.status(500).json({ error: 'Failed to delete user', message: error.message });
  }
});

// Verify Firebase token (for authenticated requests)
apiRouter.post('/auth/verify', async (req, res) => {
  try {
    if (!admin.apps.length) {
      return res.status(503).json({ error: 'Firebase Admin not configured' });
    }

    const { idToken } = req.body;
    if (!idToken) {
      return res.status(400).json({ error: 'ID token is required' });
    }

    const decodedToken = await admin.auth().verifyIdToken(idToken);
    res.json({ success: true, user: decodedToken });
  } catch (error) {
    console.error('Error verifying token:', error);
    res.status(401).json({ error: 'Invalid token', message: error.message });
  }
});

// Send OTP email
apiRouter.post('/otp/send', async (req, res) => {
  try {
    const { email, otpCode } = req.body;
    
    if (!email || !otpCode) {
      return res.status(400).json({ error: 'Email and OTP code are required' });
    }

    // Configure email transporter
    // For Gmail, you need to use App Password (not regular password)
    // 1. Go to Google Account > Security > 2-Step Verification
    // 2. Generate an App Password
    // 3. Use that password in EMAIL_APP_PASSWORD
    
    if (!process.env.EMAIL_USER || !process.env.EMAIL_APP_PASSWORD) {
      console.warn('⚠️  Email credentials not configured. OTP email will not be sent.');
      console.warn('   Set EMAIL_USER and EMAIL_APP_PASSWORD in .env file');
      return res.status(503).json({ 
        error: 'Email service not configured',
        message: 'Please configure EMAIL_USER and EMAIL_APP_PASSWORD in server .env file. See README_EMAIL_SETUP.md for instructions.'
      });
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
    res.json({ success: true, message: 'OTP email sent successfully' });
  } catch (error) {
    console.error('Error sending OTP email:', error);
    res.status(500).json({ error: 'Failed to send OTP email', message: error.message });
  }
});

// Mount API routes
app.use('/api', apiRouter);

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Server error:', err);
  res.status(500).json({ error: 'Internal server error', message: err.message });
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`📍 Health check: http://localhost:${PORT}/health`);
  console.log(`📍 API base: http://localhost:${PORT}/api`);
});

module.exports = app;
