import mongoose from "mongoose";

const busLocationSchema = new mongoose.Schema(
  {
    bus_id: {
      type: String,
      ref: "Bus",
      required: true,
    },
    latitude: { type: Number, required: true },
    longitude: { type: Number, required: true },
    speed: { type: Number },
    recorded_at: { type: Date, default: Date.now },
  },
  { timestamps: true },
);

export default mongoose.model("BusLocation", busLocationSchema);
