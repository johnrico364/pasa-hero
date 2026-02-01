import mongoose from "mongoose";

const busSchema = new mongoose.Schema(
  {
    bus_number: { type: String, required: true },
    plate_number: { type: String, required: true },
    capacity: { type: Number, required: true },
    status: { type: String, default: "active" },
  },
  { timestamps: true },
);

export default mongoose.model("Bus", busSchema);
