import validator from "validator";
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import fs from "fs";
import path from "path";

import User from "./user.model.js"; // Model

export const UserService = {
  // SIGNUP USER ===================================================================
  async signupUser(data, userImage) {
    let img_path;
    if (userImage) {
      img_path = path.join("images/users", userImage);
    }

    // Validations
    if (!validator.isEmail(data.email)) {
      if (img_path) {
        fs.unlink(img_path, (err) => {
          if (err) throw err;
          console.log("user img delete");
        });
      }
      throw Error("Invalid Email Format");
    }
    if (!validator.isStrongPassword(data.password)) {
      if (img_path) {
        fs.unlink(img_path, (err) => {
          if (err) throw err;
          console.log("user img delete");
        });
      }
      throw Error(
        "Password must contains one capital letter and one special character",
      );
    }

    const checkEmail = await User.findOne({ email: data.email });
    if (checkEmail) {
      const error = new Error("Email already exists");
      error.statusCode = 400;
      throw error;
    }

    // Hash and Salt Password
    const salt = await bcrypt.genSalt(10);
    const hashPassword = await bcrypt.hash(data.password, salt);

    // Create User
    const createUser = await User.create({
      ...data,
      password: hashPassword,
      profile_image: userImage,
    });
    return createUser;
  },
  // LOGIN USER ====================================================================
  async loginUser(data) {
    // Validations
    const user = await User.findOne({ email: data.email });
    if (!user) {
      const error = new Error("Email not found");
      throw error;
    }

    const isMatch = await bcrypt.compare(data.password, user.password);
    if (!isMatch) {
      const error = new Error("Invalid password");
      throw error;
    }

    return user;
  },
  // LOGOUT USER ====================================================================
  async logoutUser(id) {
    let user;

    user = await User.findById(id);
    if (!user) {
      throw new Error("User not found");
    }
    user = await User.findByIdAndUpdate(id, { status: "inactive" });

    return user;
  },
};
