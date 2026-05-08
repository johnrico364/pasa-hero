"use client";

import type { Dispatch, SetStateAction } from "react";
import { useEffect, useMemo, useRef, useState } from "react";
import {
  DndContext,
  KeyboardSensor,
  PointerSensor,
  closestCenter,
  useSensor,
  useSensors,
  type DragEndEvent,
} from "@dnd-kit/core";
import {
  SortableContext,
  arrayMove,
  sortableKeyboardCoordinates,
  useSortable,
  verticalListSortingStrategy,
} from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";
import { useJsApiLoader } from "@react-google-maps/api";
import AddBusStop from "./AddBusStop";
import DeleteBusStop from "./DeleteBusStop";
import EditBusStop from "./EditBusStop";
import RouteStopsMap from "./RouteStopsMap";
import { useGetRouteStops } from "../_hooks/useGetRouteStops";
import { useReorderRouteStops } from "../_hooks/useReorderRouteStops";
import {
  googleMapsApiKey,
  isGoogleMapsConfigured,
} from "@/lib/firebaseClient";
import {
  GOOGLE_MAPS_LIBRARIES,
  GOOGLE_MAPS_SCRIPT_ID,
} from "@/lib/googleMaps";
import { FaEdit, FaGripVertical, FaTrash } from "react-icons/fa";

type RouteStopType = {
  _id: string;
  stop_name: string;
  stop_order: number;
  latitude: number;
  longitude: number;
};

function normalizeStopOrder(stops: RouteStopType[]) {
  return stops
    .slice()
    .sort((a, b) => a.stop_order - b.stop_order)
    .map((stop, index) => ({ ...stop, stop_order: index + 1 }));
}

type SortableStopRowProps = {
  stop: RouteStopType;
  savingOrder: boolean;
  onEditStop: (stop: RouteStopType) => void;
  onDeleteStop: (stop: RouteStopType) => void;
};

function SortableStopRow({
  stop,
  savingOrder,
  onEditStop,
  onDeleteStop,
}: SortableStopRowProps) {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id: stop._id, disabled: savingOrder });

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.55 : 1,
    zIndex: isDragging ? 1 : undefined,
  };

  return (
    <tr ref={setNodeRef} style={style} {...attributes}>
      <td className="w-28">
        <div className="flex items-center gap-2">
          <button
            type="button"
            className="btn btn-ghost btn-square btn-sm cursor-grab touch-none text-base-content/60 active:cursor-grabbing"
            aria-label={`Drag to reorder ${stop.stop_name}`}
            disabled={savingOrder}
            {...listeners}
          >
            <FaGripVertical className="size-4" />
          </button>
          <span className="font-semibold tabular-nums">{stop.stop_order}</span>
        </div>
      </td>
      <td>{stop.stop_name}</td>
      <td className="text-xs text-base-content/70 tabular-nums">
        {stop.latitude.toFixed(4)}
      </td>
      <td className="text-xs text-base-content/70 tabular-nums">
        {stop.longitude.toFixed(4)}
      </td>
      <td className="w-40">
        <div className="flex gap-2">
          <button
            type="button"
            className="btn bg-blue-400 text-white rounded-lg"
            aria-label={`Edit ${stop.stop_name}`}
            disabled={savingOrder}
            onClick={() => onEditStop(stop)}
          >
            <FaEdit />
          </button>
          <button
            type="button"
            className="btn bg-red-400 text-white rounded-lg"
            aria-label={`Delete ${stop.stop_name}`}
            disabled={savingOrder}
            onClick={() => onDeleteStop(stop)}
          >
            <FaTrash />
          </button>
        </div>
      </td>
    </tr>
  );
}

type RouteStopsProps = {
  routeId: string;
  routeMongoId?: string;
  onToast: Dispatch<SetStateAction<string | null>>;
};

export default function RouteStops({
  routeId,
  routeMongoId,
  onToast,
}: RouteStopsProps) {
  const { getRouteStops } = useGetRouteStops();
  const { reorderRouteStops } = useReorderRouteStops();
  const getRouteStopsRef = useRef(getRouteStops);
  const [stops, setStops] = useState<RouteStopType[]>([]);
  const [baselineOrderIds, setBaselineOrderIds] = useState<string[]>([]);
  const [savingOrder, setSavingOrder] = useState(false);
  const [editingStop, setEditingStop] = useState<RouteStopType | null>(null);
  const [deletingStop, setDeletingStop] = useState<RouteStopType | null>(null);

  const sensors = useSensors(
    useSensor(PointerSensor, {
      activationConstraint: { distance: 8 },
    }),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    }),
  );

  const { isLoaded: isGoogleMapsLoaded, loadError: googleMapsLoadError } =
    useJsApiLoader({
      id: GOOGLE_MAPS_SCRIPT_ID,
      googleMapsApiKey: isGoogleMapsConfigured ? googleMapsApiKey : "",
      libraries: GOOGLE_MAPS_LIBRARIES,
    });

  useEffect(() => {
    getRouteStopsRef.current = getRouteStops;
  }, [getRouteStops]);

  useEffect(() => {
    const fetchRouteStops = async () => {
      const data = await getRouteStopsRef.current(routeId);
      if (data.success) {
        const normalized = normalizeStopOrder(data.data as RouteStopType[]);
        setStops(normalized);
        setBaselineOrderIds(normalized.map((s) => s._id));
      } else {
        onToast(data.message);
        setTimeout(() => onToast(null), 3500);
      }
    };
    fetchRouteStops();
  }, [routeId, onToast]);

  const activeStops = useMemo(() => normalizeStopOrder(stops), [stops]);
  const sortableIds = useMemo(
    () => activeStops.map((s) => s._id),
    [activeStops],
  );

  const currentOrderIds = useMemo(
    () => activeStops.map((s) => s._id),
    [activeStops],
  );

  const hasUnsavedReorder = useMemo(() => {
    if (currentOrderIds.length !== baselineOrderIds.length) return true;
    return currentOrderIds.some((id, i) => id !== baselineOrderIds[i]);
  }, [currentOrderIds, baselineOrderIds]);

  const addBusStopRows = useMemo(
    () =>
      activeStops.map((s) => ({
        id: s._id,
        stopName: s.stop_name,
        stopOrder: s.stop_order,
        latitude: s.latitude,
        longitude: s.longitude,
      })),
    [activeStops],
  );

  async function onAddRouteStop() {
    return { ok: false as const, message: "Not implemented" };
  }

  function handleDragEnd(event: DragEndEvent) {
    const { active, over } = event;
    if (!over || active.id === over.id) return;

    const sorted = normalizeStopOrder(stops);
    const ids = sorted.map((s) => s._id);
    const oldIndex = ids.indexOf(String(active.id));
    const newIndex = ids.indexOf(String(over.id));
    if (oldIndex === -1 || newIndex === -1) return;

    const reorderedIds = arrayMove(ids, oldIndex, newIndex);
    const reorderedStops = reorderedIds
      .map((id) => sorted.find((s) => s._id === id)!)
      .map((stop, index) => ({ ...stop, stop_order: index + 1 }));

    setStops(reorderedStops);
  }

  async function handleSaveBusStops() {
    if (activeStops.length === 0 || !hasUnsavedReorder) return;

    const orderedStopIds = activeStops.map((s) => s._id);
    const apiRouteId = routeMongoId ?? routeId;
    setSavingOrder(true);
    const res = await reorderRouteStops(apiRouteId, orderedStopIds);
    setSavingOrder(false);

    if (res && "success" in res && res.success && Array.isArray(res.data)) {
      const normalized = normalizeStopOrder(res.data as RouteStopType[]);
      setStops(normalized);
      setBaselineOrderIds(normalized.map((s) => s._id));
      onToast("Bus stop order saved.");
      setTimeout(() => onToast(null), 2600);
    } else {
      const message =
        res && typeof res === "object" && "message" in res
          ? String((res as { message?: string }).message)
          : "Failed to save stop order";
      onToast(message);
      setTimeout(() => onToast(null), 3500);
    }
  }

  function handleStopNameUpdated(updated: RouteStopType) {
    setStops((prev) =>
      normalizeStopOrder(
        prev.map((s) => (s._id === updated._id ? { ...s, ...updated } : s)),
      ),
    );
  }

  function handleStopDeleted(stopId: string) {
    setStops((prev) => normalizeStopOrder(prev.filter((s) => s._id !== stopId)));
    setBaselineOrderIds((prev) => prev.filter((id) => id !== stopId));
    setEditingStop((current) => (current?._id === stopId ? null : current));
  }

  return (
    <div className="rounded-xl border border-base-300 bg-base-100 p-4 shadow-sm">
      <div className="mb-3 flex flex-wrap items-start justify-between gap-3">
        <div>
          <h2 className="text-lg font-semibold">Route stops</h2>
          <p className="text-sm text-base-content/70">
            Drag the handle to reorder, then save to update the server.
          </p>
        </div>
        {activeStops.length > 0 ? (
          <button
            type="button"
            className="btn bg-[#0062CA] text-white disabled:bg-[#0062CA]/50 shrink-0"
            disabled={!hasUnsavedReorder || savingOrder}
            onClick={handleSaveBusStops}
          >
            {savingOrder ? (
              <span className="loading loading-spinner loading-sm" />
            ) : null}
            Save bus stops
          </button>
        ) : null}
      </div>

      {activeStops.length > 0 ? (
        isGoogleMapsConfigured ? (
          googleMapsLoadError ? (
            <p className="mb-3 text-sm text-error">
              Failed to load Google Maps. Check your API key and restrictions.
            </p>
          ) : isGoogleMapsLoaded ? (
            <div className="mb-3 overflow-hidden rounded-xl border border-base-300">
              <RouteStopsMap stops={activeStops} />
            </div>
          ) : (
            <p className="mb-3 text-xs text-base-content/60">Loading map...</p>
          )
        ) : (
          <p className="mb-3 text-xs text-base-content/60">
            Add{" "}
            <code className="mx-1">NEXT_PUBLIC_GOOGLE_MAPS_API_KEY</code> to your
            env file to show the stops map.
          </p>
        )
      ) : null}

      <AddBusStop
        routeId={routeMongoId ?? routeId}
        activeStops={addBusStopRows}
        onAddStop={onAddRouteStop}
        onToast={onToast}
      />

      <EditBusStop
        key={editingStop?._id ?? "edit-stop-closed"}
        stop={editingStop}
        onClose={() => setEditingStop(null)}
        onToast={onToast}
        onUpdated={handleStopNameUpdated}
      />

      <DeleteBusStop
        key={deletingStop?._id ?? "delete-stop-closed"}
        stop={
          deletingStop
            ? { _id: deletingStop._id, stop_name: deletingStop.stop_name }
            : null
        }
        onClose={() => setDeletingStop(null)}
        onToast={onToast}
        onDeleted={handleStopDeleted}
      />

      <DndContext
        sensors={sensors}
        collisionDetection={closestCenter}
        onDragEnd={handleDragEnd}
      >
        <div className="overflow-x-auto">
          <table className="table table-zebra w-full">
            <thead>
              <tr>
                <th>Order</th>
                <th>Stop name</th>
                <th>Lat</th>
                <th>Long</th>
                <th className="w-40">Actions</th>
              </tr>
            </thead>
            <tbody>
              {activeStops.length === 0 ? (
                <tr key="no-stops">
                  <td
                    colSpan={5}
                    className="text-center text-sm text-base-content/60"
                  >
                    No route stops yet. Add a stop above.
                  </td>
                </tr>
              ) : (
                <SortableContext
                  items={sortableIds}
                  strategy={verticalListSortingStrategy}
                >
                  {activeStops.map((stop) => (
                    <SortableStopRow
                      key={stop._id}
                      stop={stop}
                      savingOrder={savingOrder}
                      onEditStop={setEditingStop}
                      onDeleteStop={setDeletingStop}
                    />
                  ))}
                </SortableContext>
              )}
            </tbody>
          </table>
        </div>
      </DndContext>
    </div>
  );
}
