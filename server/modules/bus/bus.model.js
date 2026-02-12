import mongoose from "mongoose";

const busSchema = new mongoose.Schema(
  {
    bus_number: { type: String, required: true },
    plate_number: { type: String, required: true },
    capacity: { type: Number, required: true },
    status: {
      type: String,
      default: "active",
      enum: ["active", "maintenance", "out of service"],
    },
    is_deleted: { type: Boolean, default: false },
    deleted_at: { type: Date, default: null },
  },
  { timestamps: true },
);

export default mongoose.model("Bus", busSchema);
