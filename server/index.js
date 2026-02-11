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
import busRoutes from "./modules/bus/bus.route.js";

const app = express();

// Middleware
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000', 'http://localhost:5173'],
  credentials: true,
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
app.use("/api/buses", busRoutes);

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
