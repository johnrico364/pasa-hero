import { TerminalService } from "./terminal.service.js";

export const getAllTerminals = async (req, res) => {
  try {
    const terminals = await TerminalService.getAllTerminals();
    res.status(200).json({ success: true, data: terminals });
  } catch (error) {
    res.status(400).json({ success: false, message: error.message });
  }
};

export const createTerminal = async (req, res) => {
  try {
    const terminalData = req.body;
    const terminal = await TerminalService.createTerminal(terminalData);
    res.status(201).json({ success: true, data: terminal });
  } catch (error) {
    res.status(400).json({ success: false, message: error.message });
  }
};

export const getTerminalById = async (req, res) => {
  try {
    const terminalId = req.params.id;
    const terminal = await TerminalService.getTerminalById(terminalId);
    res.status(200).json({ success: true, data: terminal });
  } catch (error) {
    res.status(400).json({ success: false, message: error.message });
  }
};

export const updateTerminalById = async (req, res) => {
  try {
    const terminalId = req.params.id;
    const updateData = req.body;
    const terminal = await TerminalService.updateTerminalById(terminalId, updateData);
    res.status(200).json({ success: true, data: terminal });
  } catch (error) {
    res.status(400).json({ success: false, message: error.message });
  }
};