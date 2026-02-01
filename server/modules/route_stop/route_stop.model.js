import mongoose from "mongoose";

const routeStopSchema = new mongoose.Schema(
  {
    route_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Route",
      required: true,
    },
    stop_name: { type: String, required: true },
    stop_order: { type: Number, required: true },
    latitude: { type: Number, required: true },
    longitude: { type: Number, required: true },
  },
  { timestamps: true },
);

export default mongoose.model("RouteStop", routeStopSchema);
