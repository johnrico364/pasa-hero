import Route from "./route.model.js"; // Model

export const RouteService = {
  // GET ALL ROUTES ===================================================================
  async getAllRoutes() {
    const routes = await Route.find()
      .populate("start_terminal_id")
      .populate("end_terminal_id");
    return routes;
  },
  // CREATE ROUTE ===================================================================
  async createRoute(routeData) {
    if (routeData.start_terminal_id == routeData.end_terminal_id) {
      const error = new Error("Start and end terminals cannot be the same.");
      error.statusCode = 400;
      throw error;
    }

    const duplicateRoute = await Route.findOne({
      start_terminal_id: routeData.start_terminal_id,
      end_terminal_id: routeData.end_terminal_id,
    });
    if (duplicateRoute) {
      const error = new Error("This route already exists.");
      error.statusCode = 409;
      throw error;
    }

    const route = await Route.create(routeData);
    return route;
  },
  // GET ROUTE BY ID ===================================================================
  async getRouteById(id) {
    const route = await Route.findById(id)
      .populate("start_terminal_id")
      .populate("end_terminal_id");
    if (!route) {
      const error = new Error("Route not found.");
      error.statusCode = 404;
      throw error;
    }
    return route;
  },
};
