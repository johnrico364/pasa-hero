import { UserFirebaseService } from './user_firebase.service.js';

export const getAllUsers = async (req, res) => {
  try {
    const users = await UserFirebaseService.getAllUsers();
    res.json({ success: true, data: users, count: users.length });
  } catch (error) {
    console.error('Error fetching users:', error);
    if (error.message === 'Firebase Admin not configured') {
      return res.status(503).json({ error: error.message });
    }
    res.status(500).json({ error: 'Failed to fetch users', message: error.message });
  }
};

export const getUserById = async (req, res) => {
  try {
    const user = await UserFirebaseService.getUserById(req.params.id);
    res.json({ success: true, data: user });
  } catch (error) {
    console.error('Error fetching user:', error);
    if (error.message === 'Firebase Admin not configured') {
      return res.status(503).json({ error: error.message });
    }
    if (error.message === 'User not found') {
      return res.status(404).json({ error: error.message });
    }
    res.status(500).json({ error: 'Failed to fetch user', message: error.message });
  }
};

export const updateUser = async (req, res) => {
  try {
    const result = await UserFirebaseService.updateUser(req.params.id, req.body);
    res.json({ success: true, message: result.message });
  } catch (error) {
    console.error('Error updating user:', error);
    if (error.message === 'Firebase Admin not configured') {
      return res.status(503).json({ error: error.message });
    }
    res.status(500).json({ error: 'Failed to update user', message: error.message });
  }
};

export const deleteUser = async (req, res) => {
  try {
    const result = await UserFirebaseService.deleteUser(req.params.id);
    res.json({ success: true, message: result.message });
  } catch (error) {
    console.error('Error deleting user:', error);
    if (error.message === 'Firebase Admin not configured') {
      return res.status(503).json({ error: error.message });
    }
    res.status(500).json({ error: 'Failed to delete user', message: error.message });
  }
};

export const verifyToken = async (req, res) => {
  try {
    const { idToken } = req.body;
    const decodedToken = await UserFirebaseService.verifyToken(idToken);
    res.json({ success: true, user: decodedToken });
  } catch (error) {
    console.error('Error verifying token:', error);
    if (error.message === 'Firebase Admin not configured') {
      return res.status(503).json({ error: error.message });
    }
    if (error.message === 'ID token is required') {
      return res.status(400).json({ error: error.message });
    }
    res.status(401).json({ error: 'Invalid token', message: error.message });
  }
};
