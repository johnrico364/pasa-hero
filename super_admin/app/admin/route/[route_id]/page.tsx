"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import Link from "next/link";
import { useParams } from "next/navigation";
import { GoogleMap, useJsApiLoader } from "@react-google-maps/api";
import { RouteProps, type RouteStatus } from "../RouteProps";
import { useGetRouteDetails } from "../_hooks/useGetRouteDetails";
import {
  googleMapsApiKey,
  isGoogleMapsConfigured,
} from "@/lib/firebaseClient";
import {
  GOOGLE_MAPS_LIBRARIES,
  GOOGLE_MAPS_SCRIPT_ID,
} from "@/lib/googleMaps";

type ApiTerminalRef = {
  _id?: string;
  id?: string;
  terminal_name?: string;
};

type ApiRouteStop = {
  _id: string;
  route_id: string;
  stop_name: string;
  stop_order: number;
  latitude: number;
  longitude: number;
};

type ApiRoute = {
  _id: string;
  route_name: string;
  route_code: string;
  start_terminal_id: string | ApiTerminalRef | null;
  end_terminal_id: string | ApiTerminalRef | null;
  estimated_duration?: number | null;
  status?: string;
  is_free_ride?: boolean;
  active_buses_count?: number;
  route_stops?: ApiRouteStop[];
  createdAt?: string;
  updatedAt?: string;
};

function normalizeTerminalRef(ref: string | ApiTerminalRef | null | undefined) {
  if (!ref) {
    return { id: "", name: undefined as string | undefined };
  }
  if (typeof ref === "string") {
    return { id: ref, name: undefined as string | undefined };
  }
  return {
    id: String(ref._id ?? ref.id ?? ""),
    name: ref.terminal_name,
  };
}

function mapApiRouteToProps(route: ApiRoute): RouteProps {
  const startTerminal = normalizeTerminalRef(route.start_terminal_id);
  const endTerminal = normalizeTerminalRef(route.end_terminal_id);
  const status: RouteStatus =
    route.status === "inactive" || route.status === "suspended"
      ? route.status
      : "active";

  return {
    id: String(route._id),
    route_name: route.route_name,
    route_code: route.route_code,
    start_terminal_id: startTerminal.id,
    end_terminal_id: endTerminal.id,
    start_terminal_name: startTerminal.name,
    end_terminal_name: endTerminal.name,
    estimated_duration:
      typeof route.estimated_duration === "number" ? route.estimated_duration : null,
    is_free_ride: Boolean(route.is_free_ride),
    status,
    createdAt: route.createdAt,
    updatedAt: route.updatedAt,
  };
}

function RouteStatusBadge({ status }: { status: string }) {
  const map: Record<string, string> = {
    active: "badge-success",
    inactive: "badge-ghost",
    suspended: "badge-warning",
  };
  return (
    <span className={`badge ${map[status] ?? "badge-ghost"}`}>
      {status}
    </span>
  );
}

function formatDateTime(iso: string | undefined) {
  if (!iso) return "—";
  const d = new Date(iso);
  return d.toLocaleString(undefined, {
    dateStyle: "medium",
    timeStyle: "short",
  });
}

/** Same mapId as terminal / edit route — required for AdvancedMarkerElement. */
const ROUTE_STOPS_MAP_ID = "DEMO_MAP_ID";
const ROUTE_STOPS_MAP_HEIGHT_PX = 440;
const ROUTE_STOPS_MAP_DEFAULT_CENTER = { lat: 10.3313, lng: 123.9362 };

function RouteStopsMap({ stops }: { stops: ApiRouteStop[] }) {
  const [mapInstance, setMapInstance] = useState<google.maps.Map | null>(null);
  const markersRef = useRef<google.maps.marker.AdvancedMarkerElement[]>([]);
  const polylineRef = useRef<google.maps.Polyline | null>(null);

  const syncMarkersAndBounds = useCallback(() => {
    if (!mapInstance || !window.google?.maps?.marker?.AdvancedMarkerElement) {
      return;
    }

    for (const marker of markersRef.current) {
      marker.map = null;
    }
    markersRef.current = [];

    if (polylineRef.current) {
      polylineRef.current.setMap(null);
      polylineRef.current = null;
    }

    const validStops = stops.filter(
      (s) =>
        Number.isFinite(Number(s.latitude)) && Number.isFinite(Number(s.longitude)),
    );
    if (validStops.length === 0) {
      return;
    }

    const path = validStops.map((s) => ({
      lat: Number(s.latitude),
      lng: Number(s.longitude),
    }));

    polylineRef.current = new google.maps.Polyline({
      path,
      strokeColor: "#60A5FA",
      strokeOpacity: 1,
      strokeWeight: 3,
      map: mapInstance,
    });

    for (const stop of validStops) {
      const pos = { lat: Number(stop.latitude), lng: Number(stop.longitude) };

      const pin = document.createElement("div");
      pin.style.width = "28px";
      pin.style.height = "28px";
      pin.style.borderRadius = "9999px";
      pin.style.display = "flex";
      pin.style.alignItems = "center";
      pin.style.justifyContent = "center";
      pin.style.color = "#fff";
      pin.style.fontWeight = "700";
      pin.style.fontSize = "11px";
      pin.style.boxShadow = "0 2px 6px rgba(0,0,0,0.25)";
      pin.style.background = "#0062CA";
      pin.textContent = String(stop.stop_order);

      const label = document.createElement("div");
      label.textContent = stop.stop_name;
      label.style.marginTop = "4px";
      label.style.maxWidth = "160px";
      label.style.padding = "3px 8px";
      label.style.background = "#fff";
      label.style.borderRadius = "6px";
      label.style.boxShadow = "0 2px 6px rgba(0,0,0,0.2)";
      label.style.fontSize = "11px";
      label.style.fontWeight = "600";
      label.style.color = "#111827";
      label.style.textAlign = "center";
      label.style.wordBreak = "break-word";
      label.style.lineHeight = "1.2";

      const wrap = document.createElement("div");
      wrap.style.display = "flex";
      wrap.style.flexDirection = "column";
      wrap.style.alignItems = "center";
      wrap.appendChild(pin);
      wrap.appendChild(label);

      const marker = new google.maps.marker.AdvancedMarkerElement({
        map: mapInstance,
        position: pos,
        title: `${stop.stop_name} (#${stop.stop_order})`,
        content: wrap,
      });
      markersRef.current.push(marker);
    }

    const bounds = new google.maps.LatLngBounds();
    for (const p of path) {
      bounds.extend(p);
    }
    if (path.length === 1) {
      mapInstance.setCenter(path[0]);
      mapInstance.setZoom(15);
    } else {
      mapInstance.fitBounds(bounds);
    }
  }, [mapInstance, stops]);

  useEffect(() => {
    syncMarkersAndBounds();
  }, [syncMarkersAndBounds]);

  useEffect(() => {
    return () => {
      const markers = markersRef.current;
      markersRef.current = [];
      for (let i = 0; i < markers.length; i += 1) {
        const m = markers[i];
        if (m) m.map = null;
      }
      const line = polylineRef.current;
      polylineRef.current = null;
      if (line) line.setMap(null);
    };
  }, []);

  const firstValid = stops.find(
    (s) =>
      Number.isFinite(Number(s.latitude)) && Number.isFinite(Number(s.longitude)),
  );
  const center =
    firstValid != null
      ? { lat: Number(firstValid.latitude), lng: Number(firstValid.longitude) }
      : ROUTE_STOPS_MAP_DEFAULT_CENTER;

  return (
    <GoogleMap
      center={center}
      zoom={14}
      mapContainerStyle={{
        width: "100%",
        height: `${ROUTE_STOPS_MAP_HEIGHT_PX}px`,
      }}
      options={{
        mapId: ROUTE_STOPS_MAP_ID,
        mapTypeId: "roadmap",
        streetViewControl: false,
        mapTypeControl: false,
        fullscreenControl: false,
      }}
      onLoad={(map) => setMapInstance(map)}
      onUnmount={() => {
        setMapInstance(null);
      }}
    />
  );
}

type RouteDetailsResponse = {
  success?: boolean;
  data?: ApiRoute;
  message?: string;
};

export default function RouteDetailsPage() {
  const params = useParams();
  const routeId = params?.route_id as string | undefined;

  const {
    isLoaded: isGoogleMapsLoaded,
    loadError: googleMapsLoadError,
  } = useJsApiLoader({
    id: GOOGLE_MAPS_SCRIPT_ID,
    googleMapsApiKey: isGoogleMapsConfigured ? googleMapsApiKey : "",
    libraries: GOOGLE_MAPS_LIBRARIES,
  });

  const { getRouteDetails, error: detailsError } = useGetRouteDetails();
  const [route, setRoute] = useState<RouteProps | null>(null);
  const [busCount, setBusCount] = useState(0);
  const [routeStops, setRouteStops] = useState<ApiRouteStop[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!routeId) return;

    let cancelled = false;

    (async () => {
      setLoading(true);
      setRoute(null);
      setBusCount(0);
      setRouteStops([]);

      const res = (await getRouteDetails(routeId)) as RouteDetailsResponse | null;
      if (cancelled) return;

      if (res?.success === true && res.data) {
        const raw = res.data;
        setRoute(mapApiRouteToProps(raw));
        setBusCount(Number(raw.active_buses_count ?? 0));
        const stops = Array.isArray(raw.route_stops) ? raw.route_stops : [];
        setRouteStops(
          [...stops].sort((a, b) => (a.stop_order ?? 0) - (b.stop_order ?? 0)),
        );
      } else {
        setRoute(null);
      }
      setLoading(false);
    })();

    return () => {
      cancelled = true;
    };
  }, [routeId, getRouteDetails]);

  if (!routeId) {
    return (
      <div className="space-y-4 pt-6">
        <div className="alert alert-error">
          <span>Invalid route ID.</span>
        </div>
        <Link href="/admin/route" className="btn btn-ghost">
          ← Back to routes
        </Link>
      </div>
    );
  }

  if (loading) {
    return (
      <div className="space-y-4 pt-6">
        <span className="loading loading-spinner loading-lg" />
      </div>
    );
  }

  if (!route) {
    return (
      <div className="space-y-4 pt-6">
        {detailsError ? (
          <div role="alert" className="alert alert-error text-sm">
            {detailsError}
          </div>
        ) : (
          <div className="alert alert-error">
            <span>Route not found.</span>
          </div>
        )}
        <Link href="/admin/route" className="btn btn-lg bg-[#0062CA] text-white hover:bg-[#0062CA]/80">
          ← Back to routes
        </Link>
      </div>
    );
  }

  return (
    <div className="space-y-6 pt-6">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div className="breadcrumbs text-base">
          <ul>
            <li>
              <Link href="/admin/route" className="text-base-content/70 hover:text-base-content">
                Routes
              </Link>
            </li>
            <li className="text-base-content font-medium">
              {route.route_name}
            </li>
          </ul>
        </div>
        <Link href="/admin/route" className="btn btn-lg bg-[#0062CA] text-white hover:bg-[#0062CA]/80">
          ← Back to routes
        </Link>
      </div>

      <div className="text-3xl font-bold">{route.route_name}</div>

      <div className="grid gap-4 md:grid-cols-2">
        <div className="card card-bordered bg-base-100 shadow-sm">
          <div className="card-body">
            <h2 className="card-title text-xl">Route details</h2>
            <dl className="space-y-2 text-base">
              <div>
                <dt className="text-base-content/60">ID</dt>
                <dd className="font-mono">{route.id}</dd>
              </div>
              <div>
                <dt className="text-base-content/60">Route code</dt>
                <dd className="font-mono">{route.route_code}</dd>
              </div>
              <div>
                <dt className="text-base-content/60">Status</dt>
                <dd>
                  <RouteStatusBadge status={route.status} />
                </dd>
              </div>
              <div>
                <dt className="text-base-content/60">Free ride</dt>
                <dd>{route.is_free_ride ? "Yes" : "No"}</dd>
              </div>
              <div>
                <dt className="text-base-content/60">Estimated duration</dt>
                <dd>
                  {route.estimated_duration != null
                    ? `${route.estimated_duration} minutes`
                    : "—"}
                </dd>
              </div>
              <div>
                <dt className="text-base-content/60">Buses on this route</dt>
                <dd>
                  <strong>{busCount}</strong> {busCount === 1 ? "bus" : "buses"} running
                </dd>
              </div>
              {route.createdAt && (
                <div>
                  <dt className="text-base-content/60">Created</dt>
                  <dd>{formatDateTime(route.createdAt)}</dd>
                </div>
              )}
              {route.updatedAt && (
                <div>
                  <dt className="text-base-content/60">Updated</dt>
                  <dd>{formatDateTime(route.updatedAt)}</dd>
                </div>
              )}
            </dl>
          </div>
        </div>

        <div className="card card-bordered bg-base-100 shadow-sm">
          <div className="card-body">
            <h2 className="card-title text-xl">Terminals</h2>
            <dl className="space-y-3 text-base">
              <div>
                <dt className="text-base-content/60">Start terminal</dt>
                <dd>
                  <Link
                    href={`/admin/terminal/${route.start_terminal_id}`}
                    className="link link-primary font-medium"
                  >
                    {route.start_terminal_name ?? route.start_terminal_id}
                  </Link>
                  <span className="ml-2 font-mono text-sm text-base-content/60">
                    (ID: {route.start_terminal_id})
                  </span>
                </dd>
              </div>
              <div>
                <dt className="text-base-content/60">End terminal</dt>
                <dd>
                  <Link
                    href={`/admin/terminal/${route.end_terminal_id}`}
                    className="link link-primary font-medium"
                  >
                    {route.end_terminal_name ?? route.end_terminal_id}
                  </Link>
                  <span className="ml-2 font-mono text-sm text-base-content/60">
                    (ID: {route.end_terminal_id})
                  </span>
                </dd>
              </div>
            </dl>
          </div>
        </div>
      </div>

      <div className="card card-bordered bg-base-100 shadow-sm">
        <div className="card-body">
          <h2 className="card-title text-xl">Route stops</h2>
          {routeStops.length === 0 ? (
            <p className="text-base-content/70">No stops configured for this route.</p>
          ) : (
            <>
              <p className="text-sm text-base-content/70">
                {routeStops.length} stop{routeStops.length === 1 ? "" : "s"} on this route
              </p>
              {isGoogleMapsConfigured ? (
                googleMapsLoadError ? (
                  <p className="mt-2 text-sm text-error">
                    Failed to load Google Maps. Check your API key and restrictions.
                  </p>
                ) : isGoogleMapsLoaded ? (
                  <div className="mt-3 overflow-hidden rounded-xl border border-base-300">
                    <RouteStopsMap stops={routeStops} />
                  </div>
                ) : (
                  <p className="mt-2 text-xs text-base-content/60">Loading map...</p>
                )
              ) : (
                <p className="mt-2 text-xs text-base-content/60">
                  Add <code>NEXT_PUBLIC_GOOGLE_MAPS_API_KEY</code> in your env file to show
                  the stops map.
                </p>
              )}
            </>
          )}
        </div>
      </div>

      <div className="card card-bordered bg-base-100 shadow-sm">
        <div className="card-body">
          <h2 className="card-title text-xl">Summary</h2>
          <p className="text-base-content/80 text-lg">
            This route runs from{" "}
            <strong>{route.start_terminal_name ?? route.start_terminal_id}</strong> to{" "}
            <strong>{route.end_terminal_name ?? route.end_terminal_id}</strong>
            {route.estimated_duration != null && (
              <> with an estimated travel time of <strong>{route.estimated_duration} minutes</strong>.</>
            )}
            {route.estimated_duration == null && "."}
          </p>
        </div>
      </div>
    </div>
  );
}
