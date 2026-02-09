import admin from 'firebase-admin';
import 'dotenv/config';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

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
    try {
      const serviceAccountPath = join(__dirname, '..', 'serviceAccountKey.json');
      const serviceAccountFile = readFileSync(serviceAccountPath, 'utf8');
      serviceAccount = JSON.parse(serviceAccountFile);
    } catch (fileError) {
      // File doesn't exist, that's okay
      throw new Error('Service account file not found');
    }
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

export default admin;
