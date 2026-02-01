import mongoose from "mongoose";

const terminalSchema = new mongoose.Schema(
  {
    terminal_name: { type: String, required: true },
    location_lat: { type: Number, required: true },
    location_lng: { type: Number, required: true },
    status: { type: String, default: "active" },
  },
  { timestamps: true },
);

export default mongoose.model("Terminal", terminalSchema);
