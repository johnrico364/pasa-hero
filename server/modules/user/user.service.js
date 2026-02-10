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
  // GET USER BY ID ===================================================================
  async getUserById(id) {
    const user = await User.findById(id);
    if (!user) {
      throw new Error("User not found");
    }
    return user;
    },
  // GET ALL USERS ===================================================================
  async getAllUsers() {
    const users = await User.find();
    return users;
  },
  // CREATE ADMIN USER ===============================================================
  async createAdminUser(data, userImage) {
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
      if (img_path) {
        fs.unlink(img_path, (err) => {
          if (err) throw err;
          console.log("user img delete");
        });
      }
      const error = new Error("Email already exists");
      error.statusCode = 400;
      throw error;
    }

    // Validate admin role
    const validAdminRoles = ["super admin", "operator", "terminal admin"];
    const role = data?.role || "user";
    if (!validAdminRoles.includes(role)) {
      if (img_path) {
        fs.unlink(img_path, (err) => {
          if (err) throw err;
          console.log("user img delete");
        });
      }
      throw Error("Invalid admin role. Must be one of: super admin, operator, terminal admin");
    }

    // Hash and Salt Password
    const salt = await bcrypt.genSalt(10);
    const hashPassword = await bcrypt.hash(data.password, salt);

    // Create Admin User
    const createUser = await User.create({
      ...data,
      password: hashPassword,
      profile_image: userImage,
      role: role,
    });
    return createUser;
  },
  // UPDATE USER ===================================================================
  async updateUser(id, data) {
    // Get current user data to check existing profile_image
    const user = await User.findById(id);
    let oldImage = user?.profile_image;

    // If a new image is being set and it's different from the old one, remove the old image (unless it's default.png)
    if (data?.profile_image && oldImage && data.profile_image !== oldImage && oldImage !== "default.png") {
      const imgPath = `uploads/${oldImage}`;
      fs.unlink(imgPath, (err) => {
        if (err) {
          console.error(`Error deleting old user image: ${err}`);
        } else {
          console.log("Old user image deleted");
        }
      });
    }

    const updatedUser = await User.findByIdAndUpdate(
      id,
      {
        ...data,
        profile_image: data?.profile_image,
      },
      { new: true }
    );
    return updatedUser;
  }
};
