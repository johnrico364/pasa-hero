const express = require('express');
const cors = require('cors');
const admin = require('firebase-admin');
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
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000', 'http://localhost:5173'],
  credentials: true,
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
