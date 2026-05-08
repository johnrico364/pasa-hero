import express from "express";
import { attachAuthUser } from "../../middlewear/auth.middleware.js";
import {
  getAllRoutes,
  getRoutesByTerminalId,
  createRoute,
  getRouteById,
  getRouteByRouteCode,
  updateRouteById,
  softDeleteRouteById,
} from "./route.controller.js";

const router = express.Router();

router.get('/', getAllRoutes);
router.get('/terminal/:terminalId', getRoutesByTerminalId);
router.get('/code/:routeCode', getRouteByRouteCode);
router.post('/', attachAuthUser, createRoute);
router.get('/:id', getRouteById);
router.patch('/:id', attachAuthUser, updateRouteById);
router.delete('/:id', attachAuthUser, softDeleteRouteById);

export default router;