import mongoose from "mongoose";

const busStatusSchema = new mongoose.Schema(
  {
    bus_id: {
      type: String,
      ref: "Bus",
      required: true,
    },
    occupancy_count: { type: Number },
    occupancy_status: { type: String },
    delay_minutes: { type: Number },
    is_skipping_stops: { type: Boolean, default: false },
    updated_at: { type: Date, default: Date.now },
  },
  { timestamps: true },
);

export default mongoose.model("BusStatus", busStatusSchema);
