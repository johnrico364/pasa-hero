import mongoose from "mongoose";

const notificationSchema = new mongoose.Schema(
  {
    bus_id: { type: String, ref: "Bus" },
    route_id: { type: String, ref: "Route" },
    sender_id: {
      type: String,
      ref: "User",
      required: true,
    },
    title: { type: String, required: true },
    message: { type: String, required: true },
    notification_type: { type: String },
  },
  { timestamps: true },
);

export default mongoose.model("Notification", notificationSchema);
