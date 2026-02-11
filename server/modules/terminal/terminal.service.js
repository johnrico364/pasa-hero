import Terminal from "./terminal.model.js"; // Model

export const TerminalService = {
  // GET ALL TERMINALS ===================================================================
  async getAllTerminals() {
    const terminals = await Terminal.find();
    return terminals;
  },
  // CREATE TERMINAL ===================================================================
  async createTerminal(terminalData) {
    const existingTerminal = await Terminal.findOne({ terminal_name: terminalData.terminal_name });
    if (existingTerminal) {
      throw new Error(`Terminal name "${terminalData.terminal_name}" already exists.`);
    }

    const nearTerminal = await Terminal.findOne({
      location_lat: { $gte: terminalData.location_lat - 0.0001, $lte: terminalData.location_lat + 0.0001 },
      location_lng: { $gte: terminalData.location_lng - 0.0001, $lte: terminalData.location_lng + 0.0001 },
    });
    if (nearTerminal) {
      throw new Error('A terminal is already registered at or very near this location.');
    }

    const terminal = await Terminal.create(terminalData);
    return terminal;
  },
  // GET TERMINAL BY ID ===================================================================
  async getTerminalById(terminalId) {
    const terminal = await Terminal.findById(terminalId);
    if (!terminal) {
      throw new Error('Terminal not found.');
    }
    return terminal;
  },
};
