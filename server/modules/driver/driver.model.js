import mongoose from "mongoose";

const driverSchema = new mongoose.Schema(
  {
    full_name: { type: String, required: true },
    license_number: { type: String, required: true },
    contact_number: { type: String },
    status: { type: String, default: "active" },
  },
  { timestamps: true },
);

export default mongoose.model("Driver", driverSchema);
