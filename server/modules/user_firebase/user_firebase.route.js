import express from 'express';
import {
  getAllUsers,
  getUserById,
  updateUser,
  deleteUser,
  verifyToken,
} from './user_firebase.controller.js';

const router = express.Router();

// User routes
router.get('/', getAllUsers);
router.get('/:id', getUserById);
router.put('/:id', updateUser);
router.delete('/:id', deleteUser);

// Auth routes
router.post('/auth/verify', verifyToken);

export default router;
