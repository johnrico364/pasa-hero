import express from 'express';
import { sendOtp, testEmailConfig, checkServerStatus } from './otp.controller.js';

const router = express.Router();

// Server status check (helps diagnose connection issues)
router.get('/status', checkServerStatus);

// OTP routes
router.post('/send', sendOtp);

// Test email configuration (for debugging - remove in production or add authentication)
router.get('/test-config', testEmailConfig);

export default router;
