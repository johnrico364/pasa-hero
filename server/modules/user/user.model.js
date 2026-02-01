import mongoose from "mongoose";

const userSchema = new mongoose.Schema(
  {
    role_id: {
      type: String,
      enum: ["admin", "user", "super admin"],
      required: true,
    },
    f_name: { type: String, required: true },
    l_name: { type: String, required: true },
    email: { type: String, unique: true, required: true },
    password: { type: String, required: true },
    status: { type: String, default: "active" },
  },
  { timestamps: true },
);

export default mongoose.model("User", userSchema);
