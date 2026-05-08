import { RouteService } from "./route.service.js";

export const getAllRoutes = async (req, res) => {
  try {
    const { routes, counts } = await RouteService.getAllRoutes();
    res.status(200).json({ success: true, counts, data: routes });
  } catch (error) {
    res.status(400).json({ success: false, message: error.message });
  }
};

export const getRoutesByTerminalId = async (req, res) => {
  try {
    const { terminalId } = req.params;
    const { routes, counts } = await RouteService.getRoutesByTerminalId(terminalId);
    res.status(200).json({ success: true, counts, data: routes });
  } catch (error) {
    res.status(400).json({ success: false, message: error.message });
  }
};

export const createRoute = async (req, res) => {
  try {
    const routeData = req.body;
    const route = await RouteService.createRoute(routeData, {
      actorUserId: req.user?._id ?? null,
    });
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

export const getRouteByRouteCode = async (req, res) => {
  try {
    let routeCode = req.params.routeCode ?? "";
    try {
      routeCode = decodeURIComponent(routeCode);
    } catch {
      // use raw param
    }
    const q = req.query.route_type;
    const serviceOpts = {};
    if (q === "vice_versa") serviceOpts.route_type = "vice_versa";
    else if (q === "normal") serviceOpts.route_type = "normal";
    const route = await RouteService.getRouteByRouteCode(routeCode, serviceOpts);
    res.status(200).json({ success: true, data: route });
  } catch (error) {
    const statusCode = error.statusCode || 400;
    res.status(statusCode).json({ success: false, message: error.message });
  }
};

export const updateRouteById = async (req, res) => {
  try {
    const { id } = req.params;
    const { sender_id, ...updateData } = req.body ?? {};
    const route = await RouteService.updateRouteById(id, updateData, {
      senderId: sender_id,
      actorUserId: req.user?._id ?? null,
    });
    res.status(200).json({ success: true, data: route });
  } catch (error) {
    const statusCode = error.statusCode || 400;
    res.status(statusCode).json({ success: false, message: error.message });
  }
};

export const softDeleteRouteById = async (req, res) => {
  try {
    const { id } = req.params;
    const route = await RouteService.softDeleteRouteById(id);
    res.status(200).json({
      success: true,
      data: route,
      message: "Route deleted successfully.",
    });
  } catch (error) {
    const statusCode = error.statusCode || 400;
    res.status(statusCode).json({ success: false, message: error.message });
  }
};
