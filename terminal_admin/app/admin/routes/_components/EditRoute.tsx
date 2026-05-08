"use client";

import { useEffect, useRef, useState } from "react";
import { useForm } from "react-hook-form";
import { yupResolver } from "@hookform/resolvers/yup";
import { renderToStaticMarkup } from "react-dom/server";
import { MdOutlineEdit } from "react-icons/md";
import { FaBus } from "react-icons/fa";
import {
  GoogleMap,
  useJsApiLoader,
} from "@react-google-maps/api";
import type { RouteProps } from "../RouteProps";
import {
  editRouteSchema,
  type EditRouteFormData,
} from "./addRouteSchema";
import { googleMapsApiKey, isGoogleMapsConfigured } from "@/lib/firebaseClient";
import {
  GOOGLE_MAPS_LIBRARIES,
  GOOGLE_MAPS_SCRIPT_ID,
} from "@/lib/googleMaps";
import { useUpdateRoute } from "../_hooks/useUpdateRoute";
import { useGetTerminalNames } from "../_hooks/getTerminalNames";

const EDIT_ROUTE_MODAL_ID = "edit-route-modal";
const MAP_CENTER = { lat: 10.3313, lng: 123.9362 };
const MAP_ZOOM = 14.5;
const BUS_ICON_MARKUP = renderToStaticMarkup(<FaBus size={14} color="#fff" />);

type TerminalOption = {
  id: string;
  terminal_name: string;
};

type EditRouteProps = {
  route: RouteProps;
  modalId?: string;
  onCloseModal?: () => void;
  onRouteUpdated?: () => void | Promise<void>;
  hideStartTerminalInput?: boolean;
};

type MarkerType = "start" | "end";

const defaultValues: EditRouteFormData = {
  route_name: "",
  route_code: "",
  start_terminal_id: "",
  end_terminal_id: "",
  start_location: "",
  end_location: "",
  estimated_duration: 0,
  status: "active",
  is_free_ride: false,
};

export default function EditRoute({
  route,
  modalId = EDIT_ROUTE_MODAL_ID,
  onCloseModal,
  onRouteUpdated,
  hideStartTerminalInput = false,
}: EditRouteProps) {
  const [isOpen, setIsOpen] = useState(false);
  const [selectedTool, setSelectedTool] = useState<MarkerType>("start");
  const [startMarker, setStartMarker] = useState<{ lat: number; lng: number } | null>(
    null,
  );
  const [endMarker, setEndMarker] = useState<{ lat: number; lng: number } | null>(null);
  const [mapInstance, setMapInstance] = useState<google.maps.Map | null>(null);
  const [terminalOptions, setTerminalOptions] = useState<TerminalOption[]>([]);
  const [isLoadingTerminalOptions, setIsLoadingTerminalOptions] = useState(false);
  const advancedMarkersRef = useRef<google.maps.marker.AdvancedMarkerElement[]>([]);
  const { updateRoute, error: updateRouteError } = useUpdateRoute();
  const { getTerminalNames } = useGetTerminalNames();
  const { isLoaded: isGoogleMapsLoaded, loadError: googleMapsLoadError } =
    useJsApiLoader({
      id: GOOGLE_MAPS_SCRIPT_ID,
      googleMapsApiKey: isGoogleMapsConfigured ? googleMapsApiKey : "",
      libraries: GOOGLE_MAPS_LIBRARIES,
    });

  const {
    register,
    handleSubmit,
    reset,
    setValue,
    watch,
    formState: { errors, isSubmitting },
  } = useForm<EditRouteFormData>({
    resolver: yupResolver(editRouteSchema),
    defaultValues,
  });

  function toCoordinateString(value: unknown): string {
    if (!value) return "";
    if (typeof value === "string") return value.trim();
    if (typeof value !== "object") return "";
    const location = value as { latitude?: unknown; longitude?: unknown };
    const latitude = Number(location.latitude);
    const longitude = Number(location.longitude);
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return "";
    return `${latitude.toFixed(6)}, ${longitude.toFixed(6)}`;
  }

  function parseCoordinatePair(
    value: string,
  ): { latitude: number; longitude: number } | null {
    const [latRaw, lngRaw] = value.split(",").map((part) => part.trim());
    const latitude = Number(latRaw);
    const longitude = Number(lngRaw);
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
      return null;
    }
    return { latitude, longitude };
  }

  useEffect(() => {
    let isMounted = true;

    async function fetchTerminalOptions() {
      setIsLoadingTerminalOptions(true);
      try {
        const response = await getTerminalNames();
        const rawOptions = Array.isArray(response)
          ? response
          : Array.isArray(response?.data)
            ? response.data
            : [];

        if (!isMounted) return;

        const parsedOptions: TerminalOption[] = rawOptions
          .map((terminal: unknown) => {
            const option = terminal as {
              _id?: string | number;
              id?: string | number;
              terminal_name?: string;
            };
            const terminalName = String(option.terminal_name ?? "").trim();
            if (!terminalName) return null;
            const terminalId = String(option._id ?? option.id ?? "").trim();
            if (!terminalId) return null;
            return {
              id: terminalId,
              terminal_name: terminalName,
            };
          })
          .filter(
            (option: TerminalOption | null): option is TerminalOption => option !== null,
          );

        setTerminalOptions(parsedOptions);
      } finally {
        if (isMounted) setIsLoadingTerminalOptions(false);
      }
    }

    fetchTerminalOptions();

    return () => {
      isMounted = false;
    };
  }, [getTerminalNames]);

  useEffect(() => {
    const startLocation = toCoordinateString(
      (route as RouteProps & { start_location?: unknown }).start_location,
    );
    const endLocation = toCoordinateString(
      (route as RouteProps & { end_location?: unknown }).end_location,
    );

    reset({
      route_name: route.route_name,
      route_code: route.route_code,
      start_terminal_id: route.start_terminal_id,
      end_terminal_id: route.end_terminal_id,
      start_location: startLocation,
      end_location: endLocation,
      estimated_duration: route.estimated_duration ?? undefined,
      status: route.status,
      is_free_ride: route.is_free_ride ?? false,
    });

    const parsedStart = parseCoordinatePair(startLocation);
    const parsedEnd = parseCoordinatePair(endLocation);
    setStartMarker(
      parsedStart
        ? { lat: parsedStart.latitude, lng: parsedStart.longitude }
        : null,
    );
    setEndMarker(
      parsedEnd
        ? { lat: parsedEnd.latitude, lng: parsedEnd.longitude }
        : null,
    );
  }, [route, reset]);

  async function onSubmit(data: EditRouteFormData) {
    try {
      const startTerminalId = (data.start_terminal_id ?? "").trim();
      const endTerminalId = (data.end_terminal_id ?? "").trim();
      const parsedStart = parseCoordinatePair(data.start_location);
      const parsedEnd = parseCoordinatePair(data.end_location);
      if (!parsedStart || !parsedEnd) {
        alert("Please provide valid start and end locations in lat,lng format.");
        return;
      }

      const senderId =
        typeof window !== "undefined"
          ? localStorage.getItem("terminal_admin_user_id")?.trim() || undefined
          : undefined;

      const payload = {
        route_name: data.route_name,
        route_code: data.route_code,
        start_terminal_id: startTerminalId || undefined,
        end_terminal_id: endTerminalId || "",
        start_location: parsedStart,
        end_location: parsedEnd,
        estimated_duration:
          data.estimated_duration != null ? data.estimated_duration : undefined,
        status: data.status,
        is_free_ride: Boolean(data.is_free_ride),
        sender_id: senderId,
      };

      const result = await updateRoute(route.id, payload);
      if (!result?.success) {
        throw new Error(result?.message ?? updateRouteError ?? "Failed to update route");
      }

      await onRouteUpdated?.();

      (document.getElementById(modalId) as HTMLDialogElement)?.close();
      setIsOpen(false);
      onCloseModal?.();
    } catch (err) {
      alert(err instanceof Error ? err.message : "Failed to update route");
    }
  }

  useEffect(() => {
    const el = document.getElementById(modalId) as HTMLDialogElement | null;
    if (!el) return;
    if (isOpen) {
      el.showModal();
    } else {
      el.close();
    }
    const onClose = () => {
      setIsOpen(false);
      onCloseModal?.();
    };
    el.addEventListener("close", onClose);
    return () => el.removeEventListener("close", onClose);
  }, [isOpen, modalId, onCloseModal]);

  function onMapClick(e: google.maps.MapMouseEvent) {
    if (!e.latLng) return;
    const lat = e.latLng.lat();
    const lng = e.latLng.lng();
    const locationText = `${lat.toFixed(6)}, ${lng.toFixed(6)}`;
    if (selectedTool === "start") {
      setStartMarker({ lat, lng });
      setValue("start_location", locationText, {
        shouldValidate: true,
        shouldTouch: true,
      });
      return;
    }
    setEndMarker({ lat, lng });
    setValue("end_location", locationText, {
      shouldValidate: true,
      shouldTouch: true,
    });
  }

  useEffect(() => {
    if (!mapInstance || !window.google?.maps?.marker?.AdvancedMarkerElement) {
      return;
    }

    for (const marker of advancedMarkersRef.current) {
      marker.map = null;
    }
    advancedMarkersRef.current = [];

    const markerData: Array<{
      key: MarkerType;
      point: { lat: number; lng: number } | null;
      color: string;
    }> = [
      { key: "start", point: startMarker, color: "#16a34a" },
      { key: "end", point: endMarker, color: "#dc2626" },
    ];

    markerData.forEach((item) => {
      if (!item.point) return;
      const pin = document.createElement("div");
      pin.style.width = "28px";
      pin.style.height = "28px";
      pin.style.borderRadius = "9999px";
      pin.style.display = "flex";
      pin.style.alignItems = "center";
      pin.style.justifyContent = "center";
      pin.style.color = "#fff";
      pin.style.boxShadow = "0 2px 6px rgba(0,0,0,0.25)";
      pin.style.background = item.color;
      pin.innerHTML = BUS_ICON_MARKUP;

      const marker = new google.maps.marker.AdvancedMarkerElement({
        map: mapInstance,
        position: item.point,
        title: `${item.key.toUpperCase()} (${item.point.lat.toFixed(4)}, ${item.point.lng.toFixed(4)})`,
        content: pin,
      });
      advancedMarkersRef.current.push(marker);
    });

    return () => {
      for (const marker of advancedMarkersRef.current) marker.map = null;
      advancedMarkersRef.current = [];
    };
  }, [mapInstance, startMarker, endMarker]);

  useEffect(() => {
    if (!isOpen || !mapInstance || !window.google?.maps) return;
    window.google.maps.event.trigger(mapInstance, "resize");
    if (startMarker) {
      mapInstance.setCenter(startMarker);
      return;
    }
    mapInstance.setCenter(MAP_CENTER);
  }, [isOpen, mapInstance, startMarker]);

  const watchedStartLocation = watch("start_location");
  const watchedEndLocation = watch("end_location");
  const watchedEndTerminalId = watch("end_terminal_id");

  return (
    <>
      <button
        type="button"
        className="btn btn-sm btn-outline"
        onClick={() => setIsOpen(true)}
      >
        <MdOutlineEdit className="w-5 h-5" />
        Edit
      </button>
      <dialog id={modalId} className="modal">
        <div className="modal-box w-11/12 max-w-6xl rounded-md p-5">
          <h3 className="text-xl font-semibold text-[#222222]">Edit route</h3>
          <p className="mt-1 text-sm text-[#6B7280]">
            Update route details and map points for start and end locations.
          </p>

          <form onSubmit={handleSubmit(onSubmit)} className="mt-4 space-y-3">
            <section className="rounded-md border border-[#E5E7EB] p-3.5">
              <h4 className="text-sm font-semibold text-[#4B5563]">Map</h4>
              <div className="mt-3 grid grid-cols-1 gap-3 lg:grid-cols-[1fr_250px]">
                <div className="relative min-h-[360px] overflow-hidden rounded-xl border border-[#D1D5DB] bg-[#F3F4F6]">
                  {isGoogleMapsConfigured ? (
                    googleMapsLoadError ? (
                      <div className="flex h-full items-center justify-center px-6 text-center text-sm text-error">
                        Failed to load Google Maps script. Check your API key and map
                        restrictions.
                      </div>
                    ) : isGoogleMapsLoaded ? (
                      <GoogleMap
                        center={startMarker ?? MAP_CENTER}
                        zoom={MAP_ZOOM}
                        mapContainerStyle={{
                          width: "100%",
                          minHeight: "360px",
                        }}
                        options={{
                          mapId: "DEMO_MAP_ID",
                          mapTypeId: "roadmap",
                          streetViewControl: false,
                          mapTypeControl: false,
                          fullscreenControl: false,
                        }}
                        onLoad={(map) => setMapInstance(map)}
                        onUnmount={() => setMapInstance(null)}
                        onClick={onMapClick}
                      />
                    ) : (
                      <div className="flex h-full items-center justify-center px-6 text-center text-sm text-[#6B7280]">
                        Loading map...
                      </div>
                    )
                  ) : (
                    <div className="flex h-full items-center justify-center px-6 text-center text-sm text-[#6B7280]">
                      Add{" "}
                      <code className="mx-1">NEXT_PUBLIC_GOOGLE_MAPS_API_KEY</code>{" "}
                      to show Google Map preview.
                    </div>
                  )}
                </div>

                <aside className="rounded-xl border border-[#D1D5DB] bg-white p-3">
                  <p className="text-sm font-semibold text-[#374151]">
                    Marker Toolbox
                  </p>
                  <p className="mt-1 text-xs text-[#6B7280]">
                    Choose marker type, then click on the map.
                  </p>
                  <div className="mt-3 space-y-2">
                    <button
                      type="button"
                      onClick={() => setSelectedTool("start")}
                      className={`w-full rounded-md border px-3 py-2 text-left text-sm ${
                        selectedTool === "start"
                          ? "border-green-500 bg-green-100 text-green-900"
                          : "border-green-300 bg-green-50 text-green-800"
                      }`}
                    >
                      Start point
                    </button>
                    <button
                      type="button"
                      onClick={() => setSelectedTool("end")}
                      className={`w-full rounded-md border px-3 py-2 text-left text-sm ${
                        selectedTool === "end"
                          ? "border-red-500 bg-red-100 text-red-900"
                          : "border-red-300 bg-red-50 text-red-800"
                      }`}
                    >
                      End point
                    </button>
                  </div>
                  <div className="mt-3 rounded-md bg-[#F9FAFB] p-2 text-xs text-[#4B5563]">
                    {watchedStartLocation && watchedEndLocation
                      ? `Start (${watchedStartLocation}) → End (${watchedEndLocation})`
                      : "Place start and end points on the map."}
                  </div>
                </aside>
              </div>
            </section>

            <section className="rounded-md border border-[#E5E7EB] p-3.5">
              <h4 className="text-sm font-semibold text-[#4B5563]">Route identity</h4>
              <div className="mt-3 grid grid-cols-1 gap-2.5 md:grid-cols-3">
                <div>
                  <label className="mb-1.5 block text-base font-medium text-[#2D2D2D]">
                    Route name
                  </label>
                  <input
                    type="text"
                    placeholder="e.g. North Terminal - South Terminal"
                    className={`input input-bordered h-10 min-h-10 w-full rounded-md text-sm ${errors.route_name ? "input-error" : ""}`}
                    {...register("route_name")}
                  />
                  {errors.route_name && (
                    <p className="mt-1 text-sm text-error">{errors.route_name.message}</p>
                  )}
                </div>
                <div>
                  <label className="mb-1.5 block text-base font-medium text-[#2D2D2D]">
                    Route code
                  </label>
                  <input
                    type="text"
                    placeholder="e.g. PITX-QC-05"
                    className={`input input-bordered h-10 min-h-10 w-full rounded-md text-sm ${errors.route_code ? "input-error" : ""}`}
                    {...register("route_code")}
                  />
                  {errors.route_code && (
                    <p className="mt-1 text-sm text-error">{errors.route_code.message}</p>
                  )}
                </div>
                <div>
                  <label className="mb-1.5 block text-base font-medium text-[#2D2D2D]">
                    ETA (minutes)
                  </label>
                  <input
                    type="number"
                    min={1}
                    step={1}
                    className={`input input-bordered h-10 min-h-10 w-full rounded-md text-sm ${errors.estimated_duration ? "input-error" : ""}`}
                    {...register("estimated_duration", { valueAsNumber: true })}
                  />
                  {errors.estimated_duration && (
                    <p className="mt-1 text-sm text-error">
                      {errors.estimated_duration.message}
                    </p>
                  )}
                </div>
              </div>
              <label className="mt-3 flex cursor-pointer items-center gap-2 text-sm font-medium text-[#2D2D2D]">
                <input type="checkbox" className="checkbox checkbox-sm rounded border-[#D1D5DB]" {...register("is_free_ride")} />
                Free ride
              </label>
            </section>

            <section className="rounded-md border border-[#E5E7EB] p-3.5">
              <h4 className="text-sm font-semibold text-[#4B5563]">Route coverage</h4>
              <div
                className={`mt-3 grid grid-cols-1 gap-2.5 ${hideStartTerminalInput ? "md:grid-cols-2" : "md:grid-cols-3"}`}
              >
                {!hideStartTerminalInput && (
                  <div>
                    <label className="mb-1.5 block text-base font-medium text-[#2D2D2D]">
                      Start terminal
                    </label>
                    <select
                      className={`input input-bordered h-10 min-h-10 w-full rounded-md text-sm ${errors.start_terminal_id ? "input-error" : ""}`}
                      {...register("start_terminal_id")}
                      disabled={isLoadingTerminalOptions}
                    >
                      <option value="">
                        {isLoadingTerminalOptions
                          ? "Loading terminals..."
                          : "Select start terminal"}
                      </option>
                      {terminalOptions.map((terminal) => (
                        <option key={terminal.id} value={terminal.id}>
                          {terminal.terminal_name}
                        </option>
                      ))}
                    </select>
                    {errors.start_terminal_id && (
                      <p className="mt-1 text-sm text-error">
                        {errors.start_terminal_id.message}
                      </p>
                    )}
                  </div>
                )}
                <div>
                  <label className="mb-1.5 block text-base font-medium text-[#2D2D2D]">
                    End terminal (optional)
                  </label>
                  <select
                    className={`input input-bordered h-10 min-h-10 w-full rounded-md text-sm ${errors.end_terminal_id ? "input-error" : ""}`}
                    {...register("end_terminal_id")}
                    disabled={isLoadingTerminalOptions}
                  >
                    <option value="">
                      {isLoadingTerminalOptions
                        ? "Loading terminals..."
                        : "Select end terminal (optional)"}
                    </option>
                    {terminalOptions.map((terminal) => (
                      <option key={terminal.id} value={terminal.id}>
                        {terminal.terminal_name}
                      </option>
                    ))}
                  </select>
                  {errors.end_terminal_id && (
                    <p className="mt-1 text-sm text-error">
                      {errors.end_terminal_id.message}
                    </p>
                  )}
                  <button
                    type="button"
                    className="mt-1 text-xs font-medium text-[#2563EB] hover:text-[#1D4ED8] disabled:text-[#9CA3AF]"
                    disabled={!watchedEndTerminalId}
                    onClick={() => setValue("end_terminal_id", "", { shouldValidate: true })}
                  >
                    Remove end terminal
                  </button>
                </div>
                <div className="md:col-span-1">
                  <label className="mb-1.5 block text-base font-medium text-[#2D2D2D]">
                    Status
                  </label>
                  <select
                    className={`input input-bordered h-10 min-h-10 w-full rounded-md text-sm ${errors.status ? "input-error" : ""}`}
                    {...register("status")}
                  >
                    <option value="active">Active</option>
                    <option value="inactive">Inactive</option>
                    <option value="suspended">Suspended</option>
                  </select>
                  {errors.status && (
                    <p className="mt-1 text-sm text-error">{errors.status.message}</p>
                  )}
                </div>
              </div>
              <div className="mt-2 rounded-md bg-[#F9FAFB] p-2 text-xs text-[#6B7280]">
                {watchedStartLocation && watchedEndLocation
                  ? `Start (${watchedStartLocation}) → End (${watchedEndLocation})`
                  : "Set start and end location values."}
              </div>
              <div className="mt-3 grid grid-cols-1 gap-2.5 md:grid-cols-2">
                <div>
                  <label className="mb-1.5 block text-base font-medium text-[#2D2D2D]">
                    Start location (lat, lng)
                  </label>
                  <input
                    type="text"
                    placeholder="e.g. 14.554700, 120.984200"
                    className={`input input-bordered h-10 min-h-10 w-full rounded-md text-sm ${errors.start_location ? "input-error" : ""}`}
                    {...register("start_location")}
                  />
                  {errors.start_location && (
                    <p className="mt-1 text-sm text-error">
                      {errors.start_location.message}
                    </p>
                  )}
                </div>
                <div>
                  <label className="mb-1.5 block text-base font-medium text-[#2D2D2D]">
                    End location (lat, lng)
                  </label>
                  <input
                    type="text"
                    placeholder="e.g. 14.733300, 121.050000"
                    className={`input input-bordered h-10 min-h-10 w-full rounded-md text-sm ${errors.end_location ? "input-error" : ""}`}
                    {...register("end_location")}
                  />
                  {errors.end_location && (
                    <p className="mt-1 text-sm text-error">{errors.end_location.message}</p>
                  )}
                </div>
              </div>
            </section>

            <div className="mt-5 flex items-center justify-end gap-3">
              <button
                type="button"
                className="text-sm font-semibold text-[#242424] hover:text-[#111111]"
                onClick={() => {
                  (document.getElementById(modalId) as HTMLDialogElement)?.close();
                  setIsOpen(false);
                  onCloseModal?.();
                }}
              >
                Cancel
              </button>
              <button
                type="submit"
                className="btn h-10 min-h-10 rounded-md border-none bg-[#0062CA] px-5 text-sm font-semibold text-white hover:bg-[#0052A8]"
                disabled={isSubmitting}
              >
                {isSubmitting ? "Saving..." : "Save changes"}
              </button>
            </div>
          </form>
        </div>
        <form method="dialog" className="modal-backdrop">
          <button type="submit">close</button>
        </form>
      </dialog>
    </>
  );
}
