import { OtpService } from './otp.service.js';

export const sendOtp = async (req, res) => {
  try {
    const { email, otpCode } = req.body;
    const result = await OtpService.sendOtpEmail(email, otpCode);
    res.json({ success: true, message: result.message });
  } catch (error) {
    console.error('Error sending OTP email:', error);
    if (error.message === 'Email and OTP code are required') {
      return res.status(400).json({ error: error.message });
    }
    if (error.message.includes('Email service not configured')) {
      return res.status(503).json({
        error: 'Email service not configured',
        message: error.message,
      });
    }
    res.status(500).json({ error: 'Failed to send OTP email', message: error.message });
  }
};
