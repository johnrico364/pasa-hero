import express from 'express';
import { sendOtp } from './otp.controller.js';

const router = express.Router();

// OTP routes
router.post('/send', sendOtp);

export default router;
