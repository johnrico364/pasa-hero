import mongoose from "mongoose";

const terminalLogSchema = new mongoose.Schema(
  {
    terminal_id: { type: String, ref: "Terminal", required: true },
    bus_id: { type: String, ref: "Bus", required: true },
    event_type: {
      type: String,
      required: true,
      enum: [
        "arrival_reported",
        "arrival_confirmed",
        "departure_reported",
        "departure_confirmed",
        "auto_detected",
      ],
    },

    reported_by: { type: String, ref: "User", default: null },
    confirmed_by: { type: String, ref: "User", default: null },
    auto_detected: { type: Boolean, default: false },

    status: {
      type: String,
      enum: ["pending_confirmation", "confirmed", "rejected"],
      default: "pending_confirmation",
    },

    event_time: { type: Date, required: true },
    confirmation_time: { type: Date, default: null },

    remarks: { type: String },
  },
  { timestamps: true },
);

export default mongoose.model("TerminalLog", terminalLogSchema);
