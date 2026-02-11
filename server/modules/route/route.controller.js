import { RouteService } from "./route.service.js";

export const getAllRoutes = async (req, res) => {
  try {
    const routes = await RouteService.getAllRoutes();
    res.status(200).json({ success: true, data: routes });
  } catch (error) {
    res.status(400).json({ success: false, message: error.message });
  }
};

export const createRoute = async (req, res) => {
  try {
    const routeData = req.body;
    const route = await RouteService.createRoute(routeData);
    res.status(201).json({ success: true, data: route });
  } catch (error) {
    res.status(400).json({ success: false, message: error.message });
  }
};

export const getRouteById = async (req, res) => {
  try {
    const { id } = req.params;
    const route = await RouteService.getRouteById(id);
    res.status(200).json({ success: true, data: route });
  } catch (error) {
    const statusCode = error.statusCode || 400;
    res.status(statusCode).json({ success: false, message: error.message });
  }
};
