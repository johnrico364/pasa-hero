import { BusService } from "./bus.service.js";

export const getAllBuses = async (req, res) => {
  try {
    const buses = await BusService.getAllBuses();
    res.status(200).json({ success: true, data: buses });
  } catch (error) {
    res.status(400).json({ success: false, message: error.message });
  }
};

export const getBusById = async (req, res) => {
  try {
    const { id } = req.params;
    const bus = await BusService.getBusById(id);
    res.status(200).json({ success: true, data: bus });
  } catch (error) {
    const statusCode = error.statusCode || 400;
    res.status(statusCode).json({ success: false, message: error.message });
  }
};