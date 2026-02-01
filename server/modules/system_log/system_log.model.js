import mongoose from "mongoose";

const systemLogSchema = new mongoose.Schema(
  {
    user_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    action: { type: String, required: true },
    description: { type: String },
  },
  { timestamps: true },
);

export default mongoose.model("SystemLog", systemLogSchema);
