import mongoose from "mongoose";

const busAssignmentSchema = new mongoose.Schema(
  {
    bus_id: {
      type: String,
      ref: "Bus",
      required: true,
    },
    driver_id: {
      type: String,
      ref: "Driver",
      required: true,
    },
    route_id: {
      type: String,
      ref: "Route",
      required: true,
    },
    terminal_id: {
      type: String,
      ref: "Terminal",
      required: true,
    },
    assignment_date: { type: Date, required: true },
    status: { type: String, default: "assigned" },
  },
  { timestamps: true },
);

export default mongoose.model("BusAssignment", busAssignmentSchema);
