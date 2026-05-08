import RouteStop from "./route_stop.model.js";
import Route from "../route/route.model.js";

export const RouteStopService = {
  // CREATE ROUTE STOP ===================================================================
  async createRouteStop(routeStopData) {
    const route = await Route.findOne({
      _id: routeStopData?.route_id,
      is_deleted: { $ne: true },
    });
    if (!route) {
      const error = new Error("This route does not exist.");
      error.statusCode = 404;
      throw error;
    }

    const duplicateRouteStop = await RouteStop.findOne({
      route_id: routeStopData.route_id,
      stop_name: routeStopData.stop_name,
      stop_order: routeStopData.stop_order,
    });
    if (duplicateRouteStop) {
      const error = new Error("This route stop already exists.");
      error.statusCode = 409;
      throw error;
    }

    const routeStop = await RouteStop.create(routeStopData);
    return routeStop;
  },

  // GET ROUTE STOPS BY ROUTE ID ===================================================================
  async getRouteStopsByRouteId(routeId) {
    const route = await Route.findOne({ _id: routeId, is_deleted: { $ne: true } });
    if (!route) {
      const error = new Error("This route does not exist.");
      error.statusCode = 404;
      throw error;
    }

    const routeStops = await RouteStop.find({ route_id: routeId }).sort({
      stop_order: 1,
    });
    return routeStops;
  },

  // UPDATE ROUTE STOP BY ID ===================================================================
  async updateRouteStopById(id, updateData) {
    const routeStop = await RouteStop.findById(id);
    if (!routeStop) {
      const error = new Error("Route stop not found.");
      error.statusCode = 404;
      throw error;
    }

    if (updateData.route_id) {
      const route = await Route.findOne({
        _id: updateData.route_id,
        is_deleted: { $ne: true },
      });
      if (!route) {
        const error = new Error("This route does not exist.");
        error.statusCode = 404;
        throw error;
      }
    }

    const updated = await RouteStop.findByIdAndUpdate(id, updateData, {
      new: true,
      runValidators: true,
    });
    return updated;
  },

  // DELETE ROUTE STOP BY ID ===================================================================
  async deleteRouteStopById(id) {
    const routeStop = await RouteStop.findById(id);
    if (!routeStop) {
      const error = new Error("Route stop not found.");
      error.statusCode = 404;
      throw error;
    }
    await RouteStop.findByIdAndDelete(id);
    return routeStop;
  },

  // REORDER STOPS FOR A ROUTE (sets stop_order 1..n from ordered_stop_ids) ===================================================================
  async reorderRouteStops(routeId, orderedStopIds) {
    const route = await Route.findOne({ _id: routeId, is_deleted: { $ne: true } });
    if (!route) {
      const error = new Error("This route does not exist.");
      error.statusCode = 404;
      throw error;
    }

    if (!Array.isArray(orderedStopIds)) {
      const error = new Error("ordered_stop_ids must be an array.");
      error.statusCode = 400;
      throw error;
    }

    const existing = await RouteStop.find({ route_id: routeId });
    if (existing.length === 0) {
      if (orderedStopIds.length === 0) {
        return [];
      }
      const error = new Error("This route has no stops to reorder.");
      error.statusCode = 400;
      throw error;
    }

    if (orderedStopIds.length !== existing.length) {
      const error = new Error(
        "ordered_stop_ids must list every stop for this route exactly once.",
      );
      error.statusCode = 400;
      throw error;
    }

    const validIds = new Set(existing.map((s) => String(s._id)));
    const seen = new Set();
    for (const rawId of orderedStopIds) {
      const id = String(rawId);
      if (seen.has(id)) {
        const error = new Error("ordered_stop_ids must not contain duplicates.");
        error.statusCode = 400;
        throw error;
      }
      seen.add(id);
      if (!validIds.has(id)) {
        const error = new Error(
          "ordered_stop_ids contains a stop that does not belong to this route.",
        );
        error.statusCode = 400;
        throw error;
      }
    }

    const bulkOps = orderedStopIds.map((rawId, index) => ({
      updateOne: {
        filter: { _id: rawId, route_id: routeId },
        update: { $set: { stop_order: index + 1 } },
      },
    }));

    await RouteStop.bulkWrite(bulkOps);

    return RouteStop.find({ route_id: routeId }).sort({ stop_order: 1 });
  },
};
