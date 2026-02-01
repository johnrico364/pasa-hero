import mongoose from "mongoose";

const userNotificationSchema = new mongoose.Schema(
  {
    user_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    notification_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Notification",
      required: true,
    },
    is_read: { type: Boolean, default: false },
    read_at: { type: Date },
  },
  { timestamps: true },
);

export default mongoose.model("UserNotification", userNotificationSchema);
