import express from 'express';
import cors from 'cors';
import dotenv from "dotenv";
import mongoose from "mongoose";
import admin from './config/firebase.config.js';

// Import routes
import userRoutes from "./modules/user/user.route.js";
import userFirebaseRoutes from "./modules/user_firebase/user_firebase.route.js";
import terminalRoutes from "./modules/terminal/terminal.route.js";
import routeRoutes from "./modules/route/route.route.js";
import otpRoutes from "./modules/otp/otp.route.js";

const app = express();
const PORT = process.env.PORT || 4000;

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
dotenv.config();
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

// MongoDB Connection
const _dbURI = process.env.MONGO_DB_URI;
mongoose.connect(_dbURI).then(() => {
  console.log("Connected to Mongo DB");
});

// Image static folder
app.use("/images", express.static("images"));

// API Routes
app.use('/api/users/firebase', userFirebaseRoutes);
app.use("/api/users", userRoutes);
app.use("/api/terminals", terminalRoutes);
app.use("/api/routes", routeRoutes);
app.use("/api/otp", otpRoutes);

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Server error:', err);
  res.status(500).json({ error: 'Internal server error', message: err.message });
});

// Local Server
app.listen(process.env.PORT, () =>
  console.log(`Listening to port ${process.env.PORT}`),
);

export default app;
