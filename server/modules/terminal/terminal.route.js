import express from "express";
import { getAllTerminals, createTerminal, getTerminalById } from "./terminal.controller.js";

const router = express.Router();

router.get('/', getAllTerminals);
router.post('/', createTerminal);
router.get('/:id', getTerminalById);

export default router;  