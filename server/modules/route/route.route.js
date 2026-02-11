import express from "express";
import { getAllRoutes, createRoute, getRouteById } from "./route.controller.js";

const router = express.Router();

router.get('/', getAllRoutes);
router.post('/', createRoute);
router.get('/:id', getRouteById);

export default router;