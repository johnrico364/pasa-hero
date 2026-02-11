import mongoose from "mongoose";

const busAssignmentSchema = new mongoose.Schema(
  {
    bus_id: { type: String, ref: "Bus", required: true },
    driver_id: { type: String, ref: "Driver", required: true },
    operator_user_id: { type: String, ref: "Driver", required: true }, //Bus operator ni
    route_id: { type: String, ref: "Route", required: true },

    assignment_date: { type: Date, required: true },
    status: {
      type: String,
      default: "scheduled",
      enum: [
        "scheduled",
        "active",
        "arrival_pending",
        "arrived",
        "departed",
        "completed",
        "cancelled",
      ],
    },

    arrival_time: { type: Date, default: null },
    departure_time: { type: Date, default: null },
  },
  { timestamps: true },
);

export default mongoose.model("BusAssignment", busAssignmentSchema);
