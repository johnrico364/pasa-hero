import express from "express";
import { getAllRoutes, createRoute } from "./route.controller.js";

const router = express.Router();

router.get('/', getAllRoutes);
router.post('/', createRoute);

export default router;