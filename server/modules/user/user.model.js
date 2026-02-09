import mongoose from "mongoose";

const userSchema = new mongoose.Schema(
  {
    f_name: { type: String, required: true },
    l_name: { type: String, required: true },
    email: { type: String, unique: true, required: true },
    password: { type: String, required: true },
    profile_image: { type: String, required: true },
    role: {
      type: String,
      enum: ["user", "super admin", "operator", "terminal admin"],
      default: "user",
      required: true,
    },
    status: {
      type: String,
      default: "active",
      enum: ["active", "inactive", "suspended"],
    },
  },
  { timestamps: true },
);

export default mongoose.model("User", userSchema);
