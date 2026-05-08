import express from 'express';
import cors from 'cors';
import dotenv from "dotenv";
import compression from 'compression';
import path from "path";
import { fileURLToPath } from "url";
import admin from './config/firebase.config.js';
import { connectDB } from "./db.js";

// Import routes
import userRoutes from "./modules/user/user.route.js";
import userFirebaseRoutes from "./modules/user_firebase/user_firebase.route.js";
import terminalRoutes from "./modules/terminal/terminal.route.js";
import routeRoutes from "./modules/route/route.route.js";
import busRoutes from "./modules/bus/bus.route.js";
import driverRoutes from "./modules/driver/driver.route.js";
import busStatusRoutes from "./modules/bus_status/bus_status.route.js";
import routeStopRoutes from "./modules/route_stop/route_stop.route.js";
import otpRoutes from "./modules/otp/otp.route.js";
import terminalLogRoutes from "./modules/terminal_log/terminal_log.route.js";
import busAssignmentRoutes from "./modules/bus_assignment/bus_assignment.route.js";
import notificationRoutes from "./modules/notification/notification.route.js";
import userNotificationRoutes from "./modules/user_notification/user_notification.route.js";
import userSubscriptionRoutes from "./modules/user_subscription/user_subscription.route.js";
import systemLogRoutes from "./modules/system_log/system_log.route.js";
import dashboardRoutes from "./modules/admin_dashboard/dashboard.route.js";

const app = express();
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

app.use(cors());
dotenv.config();
app.use(compression());
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

// Ensure MongoDB is connected before API handlers (avoids Mongoose buffering timeouts on Vercel)
app.use("/api", async (req, res, next) => {
  try {
    await connectDB();
    next();
  } catch (err) {
    console.error("MongoDB connection error:", err.message);
    res.status(503).json({
      success: false,
      message: "Database unavailable",
      detail: err.message,
    });
  }
});

// Image static folder
const imagesDir = path.join(__dirname, "images");
app.use("/images", express.static(imagesDir));

// API Routes
app.use('/api/users/firebase', userFirebaseRoutes);
app.use("/api/otp", otpRoutes)
app.use("/api/users", userRoutes);
app.use("/api/terminals", terminalRoutes);
app.use("/api/routes", routeRoutes);
app.use("/api/buses", busRoutes);
app.use("/api/drivers", driverRoutes);
app.use("/api/bus-status", busStatusRoutes);
app.use("/api/route-stops", routeStopRoutes);;
app.use("/api/terminal-logs", terminalLogRoutes);
app.use("/api/bus-assignments", busAssignmentRoutes);
app.use("/api/notifications", notificationRoutes);
app.use("/api/user-notifications", userNotificationRoutes);
app.use("/api/user-subscriptions", userSubscriptionRoutes);
app.use("/api/system-logs", systemLogRoutes);
app.use("/api/admin-dashboard", dashboardRoutes);

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Server error:', err);
  res.status(500).json({ error: 'Internal server error', message: err.message });
});

// Local server only — Vercel invokes the exported app without listening
if (process.env.VERCEL !== "1") {
  const port = process.env.PORT ?? 3000;
  app.listen(port, () => console.log(`Listening to port ${port}`));
}

export default app;
