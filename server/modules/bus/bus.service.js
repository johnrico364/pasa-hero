import Bus from "./bus.model.js";

export const BusService = {
  // GET ALL BUSES ===================================================================
  async getAllBuses() {
    const buses = await Bus.find();
    return buses;
  },
  // GET BUS BY ID ===================================================================
  async getBusById(id) {
    const bus = await Bus.findById(id);
    if (!bus) {
      const error = new Error("Bus not found.");
      error.statusCode = 404;
      throw error;
    }
    return bus;
  },
};
