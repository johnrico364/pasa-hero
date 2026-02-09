import admin from '../../config/firebase.config.js';

export const UserFirebaseService = {
  // GET ALL USERS ===================================================================
  async getAllUsers() {
    if (!admin.apps.length) {
      throw new Error('Firebase Admin not configured');
    }

    const db = admin.firestore();
    const usersSnapshot = await db.collection('users').get();
    const users = usersSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    }));

    return users;
  },

  // GET USER BY ID ===================================================================
  async getUserById(id) {
    if (!admin.apps.length) {
      throw new Error('Firebase Admin not configured');
    }

    const db = admin.firestore();
    const userDoc = await db.collection('users').doc(id).get();

    if (!userDoc.exists) {
      throw new Error('User not found');
    }

    return { id: userDoc.id, ...userDoc.data() };
  },

  // UPDATE USER ===================================================================
  async updateUser(id, updateData) {
    if (!admin.apps.length) {
      throw new Error('Firebase Admin not configured');
    }

    const db = admin.firestore();
    const { id: _, ...dataToUpdate } = updateData;

    await db.collection('users').doc(id).update({
      ...dataToUpdate,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { message: 'User updated successfully' };
  },

  // DELETE USER ===================================================================
  async deleteUser(id) {
    if (!admin.apps.length) {
      throw new Error('Firebase Admin not configured');
    }

    const db = admin.firestore();
    await db.collection('users').doc(id).delete();

    return { message: 'User deleted successfully' };
  },

  // VERIFY FIREBASE TOKEN ===================================================================
  async verifyToken(idToken) {
    if (!admin.apps.length) {
      throw new Error('Firebase Admin not configured');
    }

    if (!idToken) {
      throw new Error('ID token is required');
    }

    const decodedToken = await admin.auth().verifyIdToken(idToken);
    return decodedToken;
  },
};
