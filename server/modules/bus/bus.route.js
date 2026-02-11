import express from "express";
import { getAllBuses, getBusById, createBus } from "./bus.controller.js";

const router = express.Router();

router.get('/', getAllBuses);
router.get('/:id', getBusById);
router.post('/', createBus);

export default router;