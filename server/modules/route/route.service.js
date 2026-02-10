import Route from "./route.model.js"; // Model

export const RouteService = {
    // GET ALL ROUTES ===================================================================
    async getAllRoutes() {
        const routes = await Route.find().populate("start_terminal_id").populate("end_terminal_id");
        return routes;
    },
};