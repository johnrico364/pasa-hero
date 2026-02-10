import express from "express";
import { getAllTerminals, createTerminal } from "./terminal.controller.js";

const router = express.Router();

router.get('/', getAllTerminals);
router.post('/', createTerminal);

export default router;  