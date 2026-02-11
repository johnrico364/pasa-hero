import express from "express";
import { getAllTerminals, createTerminal, getTerminalById, updateTerminalById } from "./terminal.controller.js";

const router = express.Router();

router.get('/', getAllTerminals);
router.post('/', createTerminal);
router.get('/:id', getTerminalById);
router.patch('/:id', updateTerminalById);

export default router;  