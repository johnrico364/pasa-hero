import mongoose from "mongoose";

const terminalLogSchema = new mongoose.Schema(
  {
    terminal_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Terminal",
      required: true,
    },
    bus_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Bus",
      required: true,
    },
    event_type: { type: String, required: true },
    event_time: { type: Date, default: Date.now },
    remarks: { type: String },
  },
  { timestamps: true },
);

export default mongoose.model("TerminalLog", terminalLogSchema);
