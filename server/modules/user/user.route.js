import express from "express";
import upload from "../../middlewear/multer.js";
import { signupUser, loginUser, logoutUser, getUserById, getAllUsers, createAdminUser } from "./user.controller.js";

const router = express.Router();

// auth routes (user side)
router.post("/auth/signup", upload.single("image"), signupUser);
router.post("/auth/signin", loginUser);
router.patch("/auth/logout/:id", logoutUser);
router.get('/auth/:id', getUserById);

// User Management Routes
router.get('/', getAllUsers);
router.post('/', upload.single("image"), createAdminUser);

export default router;
