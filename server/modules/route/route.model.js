import mongoose from "mongoose";

const routeSchema = new mongoose.Schema(
  {
    route_name: { type: String, required: true },
    start_terminal_id: { type: String, ref: "Terminal", required: true },
    end_terminal_id: { type: String, ref: "Terminal", required: true },
    estimated_duration: { type: Number }, // minutes
    status: {
      type: String,
      default: "active",
      enum: ["active", "inactive", "suspended"],
    },
  },
  { timestamps: true },
);

export default mongoose.model("Route", routeSchema);
