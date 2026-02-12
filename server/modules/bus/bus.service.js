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
  // CREATE BUS ===================================================================
  async createBus(busData) {
    const existing = await Bus.findOne({
      $or: [
        { bus_number: busData.bus_number },
        { plate_number: busData.plate_number },
      ],
    });
    if (existing) {
      const error = new Error(
        existing.plate_number === busData.plate_number
          ? "A bus with this plate number already exists."
          : "A bus with this bus number already exists.",
      );
      error.statusCode = 409;
      throw error;
    }
    const bus = await Bus.create(busData);
    return bus;
  },
  // UPDATE BUS BY ID ===================================================================
  async updateBusById(id, updateData) {
    const bus = await Bus.findById(id);
    if (!bus) {
      const error = new Error("Bus not found.");
      error.statusCode = 404;
      throw error;
    }
    const bus_number = updateData.bus_number ?? bus.bus_number;
    const plate_number = updateData.plate_number ?? bus.plate_number;
    const existing = await Bus.findOne({
      _id: { $ne: id },
      $or: [
        { bus_number },
        { plate_number },
      ],
    });
    if (existing) {
      const error = new Error(
        existing.plate_number === plate_number
          ? "A bus with this plate number already exists."
          : "A bus with this bus number already exists.",
      );
      error.statusCode = 409;
      throw error;
    }
    const updated = await Bus.findByIdAndUpdate(id, updateData, {
      new: true,
      runValidators: true,
    });
    return updated;
  },
};
