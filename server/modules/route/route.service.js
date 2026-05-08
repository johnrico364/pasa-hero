import Route from "./route.model.js"; // Model
import BusAssignment from "../bus_assignment/bus_assignment.model.js";
import RouteStop from "../route_stop/route_stop.model.js";
import User from "../user/user.model.js";
import { NotificationService } from "../notification/notification.service.js";
import { logSystemEvent } from "../../utils/systemLogger.js";

function routeDisplayLabel(route) {
  if (!route) return "route";
  const code = route.route_code ? `${route.route_code}` : "";
  const name = route.route_name ? `${route.route_name}` : "";
  if (code && name) return `${name} (${code})`;
  return name || code || "route";
}

const ACTIVE_ROUTE_FILTER = { is_deleted: { $ne: true } };
const normalizeTerminalId = (value) => {
  if (value == null) return null;
  if (typeof value === "string" && value.trim() === "") return null;
  return value;
};

const terminalIdFromRouteField = (value) => {
  if (value == null) return null;
  if (typeof value === "object") {
    const id = value._id ?? value.id;
    if (id != null) {
      const s = String(id).trim();
      return s === "" ? null : s;
    }
    return null;
  }
  return normalizeTerminalId(value);
};

// Fallback sender for auto-generated notifications when the caller did not
// supply a sender_id. Resolves to the first `super admin` user, since
// Notification.sender_id is required on the schema.
let cachedSystemSenderId = null;
async function getSystemSenderId() {
  if (cachedSystemSenderId) return cachedSystemSenderId;
  const admin = await User.findOne({ role: "super admin" })
    .select("_id")
    .lean();
  cachedSystemSenderId = admin ? String(admin._id) : null;
  return cachedSystemSenderId;
}

async function emitRouteFreeNotifications(route, senderId) {
  const resolvedSender = senderId || (await getSystemSenderId());
  if (!resolvedSender) return;

  const startId = terminalIdFromRouteField(route.start_terminal_id);
  const endId = terminalIdFromRouteField(route.end_terminal_id);
  const terminals = [...new Set([startId, endId].filter(Boolean))];
  if (!terminals.length) return;

  const title = `Free ride on ${route.route_name}`;
  const message =
    `Route ${route.route_code} (${route.route_name}) is now a free ride. ` +
    `Passengers can board without fare until further notice.`;

  for (const tid of terminals) {
    await NotificationService.createNotification({
      sender_id: resolvedSender,
      route_id: String(route._id),
      terminal_id: tid,
      title,
      message,
      notification_type: "route_free",
      priority: "high",
      scope: "terminal",
    });
  }
}

async function enrichRouteWithAssignmentsAndStops(route) {
  const [busIds, routeStops] = await Promise.all([
    BusAssignment.distinct("bus_id", {
      assignment_status: "active",
      route_id: route._id,
    }),
    RouteStop.find({ route_id: String(route._id) }).sort({ stop_order: 1 }),
  ]);
  return {
    ...route.toObject(),
    active_buses_count: busIds.length,
    route_stops: routeStops.map((stop) => stop.toObject()),
  };
}

export const RouteService = {
  // GET ALL ROUTES ===================================================================
  async getAllRoutes() {
    const routeFilter = { route_type: "normal", ...ACTIVE_ROUTE_FILTER };

    const [routes, totalRoutes, activeRoutes, inactiveRoutes] = await Promise.all([
      Route.find(routeFilter).populate("start_terminal_id").populate("end_terminal_id"),
      Route.countDocuments(routeFilter),
      Route.countDocuments({ ...routeFilter, status: "active" }),
      Route.countDocuments({ ...routeFilter, status: "inactive" }),
    ]);

    const routeIds = routes.map((route) => route._id);

    const [activeBusesAcrossRoutes, activeBusesByRoute] = await Promise.all([
      BusAssignment.distinct("bus_id", {
        assignment_status: "active",
        route_id: { $in: routeIds },
      }).then((busIds) => busIds.length),
      BusAssignment.aggregate([
        { $match: { assignment_status: "active", route_id: { $in: routeIds } } },
        { $group: { _id: "$route_id", busIds: { $addToSet: "$bus_id" } } },
        { $project: { active_buses_count: { $size: "$busIds" } } },
      ]),
    ]);

    const activeBusesCountByRouteId = new Map(
      activeBusesByRoute.map((row) => [String(row._id), row.active_buses_count]),
    );

    const routesWithActiveBuses = routes.map((route) => {
      const plain = route.toObject();
      return {
        ...plain,
        active_buses_count: activeBusesCountByRouteId.get(String(route._id)) ?? 0,
      };
    });

    return {
      routes: routesWithActiveBuses,
      counts: {
        total_routes: totalRoutes,
        active_routes: activeRoutes,
        inactive_routes: inactiveRoutes,
        active_buses: activeBusesAcrossRoutes,
      },
    };
  },
  // GET ROUTES BY TERMINAL ID ==========================================================
  async getRoutesByTerminalId(terminalId) {
    const terminalFilter = {
      $or: [{ start_terminal_id: terminalId }, { end_terminal_id: terminalId }],
      route_type: "normal",
      ...ACTIVE_ROUTE_FILTER,
    };

    const routes = await Route.find(terminalFilter)
      .populate("start_terminal_id")
      .populate("end_terminal_id");

    const routeIds = routes.map((route) => route._id);

    const activeBusesByRoute = await BusAssignment.aggregate([
      { $match: { assignment_status: "active", route_id: { $in: routeIds } } },
      { $group: { _id: "$route_id", busIds: { $addToSet: "$bus_id" } } },
      { $project: { active_buses_count: { $size: "$busIds" } } },
    ]);

    const activeBusesAcrossRoutes = await BusAssignment.distinct("bus_id", {
      assignment_status: "active",
      route_id: { $in: routeIds },
    }).then((busIds) => busIds.length);

    const [totalRoutes, activeRoutes, inactiveRoutes] = await Promise.all([
      Route.countDocuments(terminalFilter),
      Route.countDocuments({ ...terminalFilter, status: "active" }),
      Route.countDocuments({ ...terminalFilter, status: "inactive" }),
    ]);

    const activeBusesCountByRouteId = new Map(
      activeBusesByRoute.map((row) => [String(row._id), row.active_buses_count]),
    );

    const routesWithActiveBuses = routes.map((route) => ({
      ...route.toObject(),
      active_buses_count: activeBusesCountByRouteId.get(String(route._id)) ?? 0,
    }));

    return {
      routes: routesWithActiveBuses,
      counts: {
        total_routes: totalRoutes,
        active_routes: activeRoutes,
        inactive_routes: inactiveRoutes,
        active_buses: activeBusesAcrossRoutes,
      },
    };
  },
  // CREATE ROUTE ===================================================================
  async createRoute(routeData, options = {}) {
    const { actorUserId = null } = options;
    const normalizedRouteData = {
      ...routeData,
      start_terminal_id: normalizeTerminalId(routeData.start_terminal_id),
      end_terminal_id: normalizeTerminalId(routeData.end_terminal_id),
    };
    const normalizedRouteType =
      normalizedRouteData.route_type === "vice_versa" ? "vice_versa" : "normal";
    const primaryRouteData = { ...normalizedRouteData, route_type: normalizedRouteType };
    const reverseRouteType = normalizedRouteType === "normal" ? "vice_versa" : "normal";

    if (normalizedRouteData.start_terminal_id == normalizedRouteData.end_terminal_id) {
      const error = new Error("Start and end terminals cannot be the same.");
      error.statusCode = 400;
      throw error;
    }

    const duplicateRoute = await Route.findOne({
      start_terminal_id: normalizedRouteData.start_terminal_id,
      end_terminal_id: normalizedRouteData.end_terminal_id,
      ...ACTIVE_ROUTE_FILTER,
    });
    if (duplicateRoute) {
      const error = new Error("This route already exists.");
      error.statusCode = 409;
      throw error;
    }

    const duplicateRouteCode = await Route.findOne({
      route_code: routeData.route_code,
      ...ACTIVE_ROUTE_FILTER,
    });
    if (duplicateRouteCode) {
      const error = new Error("This route code already exists.");
      error.statusCode = 409;
      throw error;
    }

    const reverseRouteData = {
      ...primaryRouteData,
      start_terminal_id: normalizedRouteData.end_terminal_id,
      end_terminal_id: normalizedRouteData.start_terminal_id ?? null,
      start_location: normalizedRouteData.end_location ?? null,
      end_location: normalizedRouteData.start_location ?? null,
      route_type: reverseRouteType,
    };

    if (typeof normalizedRouteData.route_name === "string") {
      const parts = normalizedRouteData.route_name
        .split("-")
        .map((p) => p.trim())
        .filter(Boolean);
      if (parts.length === 2) {
        reverseRouteData.route_name = `${parts[1]} - ${parts[0]}`;
      }
    }

    const session = await Route.startSession().catch(() => null);
    let createdRoute;
    if (!session) {
      createdRoute = await Route.create(primaryRouteData);

      const reverseExists = await Route.findOne({
        start_terminal_id: reverseRouteData.start_terminal_id,
        end_terminal_id: reverseRouteData.end_terminal_id,
        ...ACTIVE_ROUTE_FILTER,
      });
      if (!reverseExists) {
        await Route.create(reverseRouteData);
      }
    } else {
      try {
        await session.withTransaction(async () => {
          createdRoute = await Route.create([primaryRouteData], { session }).then(
            (docs) => docs[0],
          );

          const reverseExists = await Route.findOne(
            {
              start_terminal_id: reverseRouteData.start_terminal_id,
              end_terminal_id: reverseRouteData.end_terminal_id,
              ...ACTIVE_ROUTE_FILTER,
            },
            null,
            { session },
          );

          if (!reverseExists) {
            await Route.create([reverseRouteData], { session });
          }
        });
      } finally {
        session.endSession();
      }
    }

    if (createdRoute) {
      await logSystemEvent({
        userId: actorUserId,
        action: "Create Route",
        description: `Created route ${routeDisplayLabel(createdRoute)}.`,
      });
    }

    return createdRoute;
  },
  // GET ROUTE BY ID ===================================================================
  async getRouteById(id) {
    const route = await Route.findOne({ _id: id, ...ACTIVE_ROUTE_FILTER })
      .populate("start_terminal_id")
      .populate("end_terminal_id");
    if (!route) {
      const error = new Error("Route not found.");
      error.statusCode = 404;
      throw error;
    }
    return enrichRouteWithAssignmentsAndStops(route);
  },
  async getRouteByRouteCode(routeCode, options = {}) {
    const trimmed = typeof routeCode === "string" ? routeCode.trim() : "";
    const routeType =
      options.route_type === "vice_versa" ? "vice_versa" : "normal";
    const route = await Route.findOne({
      route_code: trimmed,
      route_type: routeType,
      ...ACTIVE_ROUTE_FILTER,
    })
      .populate("start_terminal_id")
      .populate("end_terminal_id");
    if (!route) {
      const error = new Error("Route not found.");
      error.statusCode = 404;
      throw error;
    }
    return enrichRouteWithAssignmentsAndStops(route);
  },
  // UPDATE ROUTE BY ID ===================================================================
  async updateRouteById(id, updateData, options = {}) {
    const { senderId = null, actorUserId = null } = options;
    const route = await Route.findOne({ _id: id, ...ACTIVE_ROUTE_FILTER });
    if (!route) {
      const error = new Error("Route not found.");
      error.statusCode = 404;
      throw error;
    }
    const wasFree = route.is_free_ride === true;
    const previousStatus = route.status;

    const normalizedUpdateData = { ...updateData };
    if (Object.prototype.hasOwnProperty.call(normalizedUpdateData, "start_terminal_id")) {
      normalizedUpdateData.start_terminal_id = normalizeTerminalId(
        normalizedUpdateData.start_terminal_id,
      );
    }
    if (Object.prototype.hasOwnProperty.call(normalizedUpdateData, "end_terminal_id")) {
      normalizedUpdateData.end_terminal_id = normalizeTerminalId(
        normalizedUpdateData.end_terminal_id,
      );
    }

    const hasStartTerminalUpdate = Object.prototype.hasOwnProperty.call(
      normalizedUpdateData,
      "start_terminal_id",
    );
    const hasEndTerminalUpdate = Object.prototype.hasOwnProperty.call(
      normalizedUpdateData,
      "end_terminal_id",
    );
    const start_terminal_id = hasStartTerminalUpdate
      ? normalizedUpdateData.start_terminal_id
      : normalizeTerminalId(route.start_terminal_id);
    const end_terminal_id = hasEndTerminalUpdate
      ? normalizedUpdateData.end_terminal_id
      : normalizeTerminalId(route.end_terminal_id);
    normalizedUpdateData.start_terminal_id = start_terminal_id;
    normalizedUpdateData.end_terminal_id = end_terminal_id;

    if (start_terminal_id === end_terminal_id) {
      const error = new Error("Start and end terminals cannot be the same.");
      error.statusCode = 400;
      throw error;
    }

    const duplicateRoute = await Route.findOne({
      start_terminal_id,
      end_terminal_id,
      _id: { $ne: id },
      ...ACTIVE_ROUTE_FILTER,
    });
    if (duplicateRoute) {
      const error = new Error("This route already exists.");
      error.statusCode = 409;
      throw error;
    }

    const syncStatusToSibling = Object.prototype.hasOwnProperty.call(
      normalizedUpdateData,
      "status",
    );
    const syncRouteCodeToSibling = Object.prototype.hasOwnProperty.call(
      normalizedUpdateData,
      "route_code",
    );
    const syncFreeRideToSibling = Object.prototype.hasOwnProperty.call(
      normalizedUpdateData,
      "is_free_ride",
    );
    let siblingId = null;
    if (syncStatusToSibling || syncRouteCodeToSibling || syncFreeRideToSibling) {
      const siblingType = route.route_type === "normal" ? "vice_versa" : "normal";
      const sibling = await Route.findOne({
        route_code: route.route_code,
        route_type: siblingType,
        _id: { $ne: id },
        ...ACTIVE_ROUTE_FILTER,
      }).select("_id");
      siblingId = sibling ? sibling._id : null;
    }

    const updated = await Route.findOneAndUpdate(
      { _id: id, ...ACTIVE_ROUTE_FILTER },
      normalizedUpdateData,
      {
        new: true,
        runValidators: true,
      },
    )
      .populate("start_terminal_id")
      .populate("end_terminal_id");

    if (
      updated &&
      siblingId &&
      (syncStatusToSibling || syncRouteCodeToSibling || syncFreeRideToSibling)
    ) {
      const siblingPatch = {};
      if (syncStatusToSibling) siblingPatch.status = updated.status;
      if (syncRouteCodeToSibling) siblingPatch.route_code = updated.route_code;
      if (syncFreeRideToSibling) siblingPatch.is_free_ride = updated.is_free_ride;
      await Route.findOneAndUpdate(
        { _id: siblingId, ...ACTIVE_ROUTE_FILTER },
        siblingPatch,
        { new: true, runValidators: true },
      );
    }

    const nowFree = updated?.is_free_ride === true;
    const transitionedToFree = !wasFree && nowFree;
    if (transitionedToFree) {
      try {
        await emitRouteFreeNotifications(updated, senderId);
      } catch (err) {
        console.error(
          "[RouteService.updateRouteById] Failed to emit route_free notification:",
          err,
        );
      }
    }

    if (updated && actorUserId) {
      const newStatus = updated.status;
      const routeLabel = routeDisplayLabel(updated);
      if (newStatus === "suspended" && previousStatus !== "suspended") {
        await logSystemEvent({
          userId: actorUserId,
          action: "Suspend Route",
          description: `Suspended route ${routeLabel}.`,
        });
      } else if (newStatus === "active" && previousStatus === "suspended") {
        await logSystemEvent({
          userId: actorUserId,
          action: "Reactivate Route",
          description: `Reactivated route ${routeLabel}.`,
        });
      } else {
        const ignoredKeys = new Set(["sender_id"]);
        const changedFields = Object.keys(normalizedUpdateData || {}).filter(
          (key) =>
            !ignoredKeys.has(key) && normalizedUpdateData[key] !== undefined,
        );
        if (changedFields.length > 0) {
          await logSystemEvent({
            userId: actorUserId,
            action: "Update Route",
            description: `Updated route ${routeLabel} (fields: ${changedFields.join(", ")}).`,
          });
        }
      }
    }

    return updated;
  },

  // SOFT DELETE ROUTE BY ID ============================================================
  async softDeleteRouteById(id) {
    const route = await Route.findOne({ _id: id, ...ACTIVE_ROUTE_FILTER });
    if (!route) {
      const error = new Error("Route not found.");
      error.statusCode = 404;
      throw error;
    }

    const deletedRoute = await Route.findByIdAndUpdate(
      id,
      {
        is_deleted: true,
        deleted_at: new Date(),
        status: "inactive",
      },
      { new: true },
    )
      .populate("start_terminal_id")
      .populate("end_terminal_id");

    return deletedRoute;
  },
};
