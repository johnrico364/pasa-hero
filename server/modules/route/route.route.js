import express from "express";
import { getAllRoutes } from "./route.controller.js";

const router = express.Router();

router.get('/', getAllRoutes);

export default router;