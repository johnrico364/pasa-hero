"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { useParams } from "next/navigation";
import { FaArrowLeft, FaExchangeAlt } from "react-icons/fa";
import RouteStops from "./_components/RouteStops";
import { useGetRoute } from "./_hooks/useGetRoute";
import { useGetRouteByRouteCode } from "./_hooks/useGetRouteByRouteCode";

type RouteDetailType = {
  _id: string;
  active_buses_count: number;
  estimated_duration: number | null;
  route_code: string;
  route_name: string;
  start_terminal_id: { terminal_name: string };
  end_terminal_id: { terminal_name: string };
  status: string;
  is_free_ride?: boolean;
  route_type?: "normal" | "vice_versa";
  updatedAt: string;
};

function formatEtaMinutes(minutes: number | null | undefined) {
  if (minutes == null || !Number.isFinite(minutes) || minutes < 0) return "—";
  const rounded = Math.round(minutes);
  if (rounded < 60) return `${rounded} min`;
  const h = Math.floor(rounded / 60);
  const m = rounded % 60;
  return m ? `${h}h ${m}m` : `${h}h`;
}

function formatTimeAgo(iso: string) {
  const minutes = Math.max(
    0,
    Math.round((Date.now() - new Date(iso).getTime()) / 60_000),
  );
  if (minutes < 1) return "just now";
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  return `${days}d ago`;
}

export default function RouteDetailsPage() {
  const params = useParams();
  const routeId = params.route_id as string;

  const { getRoute } = useGetRoute();
  const getRouteRef = useRef(getRoute);
  const { getRouteByRouteCode } = useGetRouteByRouteCode();
  const getRouteByRouteCodeRef = useRef(getRouteByRouteCode);

  const [route, setRoute] = useState<RouteDetailType>();
  const [toast, setToast] = useState<string | null>(null);
  const [isTogglingDirection, setIsTogglingDirection] = useState(false);

  useEffect(() => {
    getRouteRef.current = getRoute;
  }, [getRoute]);

  useEffect(() => {
    getRouteByRouteCodeRef.current = getRouteByRouteCode;
  }, [getRouteByRouteCode]);

  useEffect(() => {
    if (!toast) return;
    const timeoutId = setTimeout(() => setToast(null), 2600);
    return () => clearTimeout(timeoutId);
  }, [toast]);

  useEffect(() => {
    const fetchRouteDetails = async () => {
      const data = await getRouteRef.current(routeId);
      if (data.success) {
        setRoute(data.data);
      } else {
        setToast(data.message);
        setTimeout(() => setToast(null), 3500);
      }
    };
    fetchRouteDetails();
  }, [routeId]);

  async function handleToggleDirection() {
    if (!route?.route_code) return;
    const currentType =
      route.route_type === "vice_versa" ? "vice_versa" : "normal";
    const oppositeType = currentType === "normal" ? "vice_versa" : "normal";
    setIsTogglingDirection(true);
    try {
      const data = await getRouteByRouteCodeRef.current(
        route.route_code,
        oppositeType,
      );
      if (data?.success) {
        setRoute(data.data as RouteDetailType);
      } else {
        setToast(
          typeof data?.message === "string" ? data.message : "Could not load route",
        );
        setTimeout(() => setToast(null), 3500);
      }
    } finally {
      setIsTogglingDirection(false);
    }
  }

  const isViceVersa = route?.route_type === "vice_versa";

  return (
    <div className="space-y-6 pb-6 pt-4">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">Route details</h1>
          <p className="text-sm text-base-content/70">
            View route profile and operational summary.
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <button
            type="button"
            className="btn btn-outline"
            disabled={!route?.route_code || isTogglingDirection}
            onClick={handleToggleDirection}
          >
            <FaExchangeAlt className="size-4" />
            {isTogglingDirection
              ? "Loading…"
              : isViceVersa
                ? "View forward direction"
                : "View reverse direction"}
          </button>
          <Link href="/admin/routes" className="btn bg-[#0062CA] text-white">
            <FaArrowLeft className="size-4" />
            Back to routes
          </Link>
        </div>
      </div>

      {toast ? (
        <div className="alert alert-success">
          <span>{toast}</span>
        </div>
      ) : null}

      <div className="space-y-4">
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <div className="rounded-lg border border-base-300 bg-base-100 p-3">
            <p className="text-xs uppercase tracking-wide text-base-content/60">
              Route code
            </p>
            <p className="mt-1 text-base font-semibold">{route?.route_code}</p>
          </div>
          <div className="rounded-lg border border-base-300 bg-base-100 p-3">
            <p className="text-xs uppercase tracking-wide text-base-content/60">
              Status
            </p>
            <p className="mt-1">
              <span
                className={`badge badge-outline capitalize ${route?.status === "active" ? "badge-success" : "badge-warning"}`}
              >
                {route?.status}
              </span>
            </p>
          </div>
          <div className="rounded-lg border border-base-300 bg-base-100 p-3">
            <p className="text-xs uppercase tracking-wide text-base-content/60">
              Free ride
            </p>
            <p className="mt-1 text-base font-medium">
              {route?.is_free_ride ? "Yes" : "No"}
            </p>
          </div>
          <div className="rounded-lg border border-base-300 bg-base-100 p-3">
            <p className="text-xs uppercase tracking-wide text-base-content/60">
              Route name
            </p>
            <p className="mt-1 text-base font-semibold">
              {route?.route_name || "—"}
            </p>
          </div>
          <div className="rounded-lg border border-base-300 bg-base-100 p-3">
            <p className="text-xs uppercase tracking-wide text-base-content/60">
              Active buses
            </p>
            <p className="mt-1 text-base font-medium">
              {route?.active_buses_count}{" "}
              {route?.active_buses_count === 1 ? "bus" : "buses"} running
            </p>
          </div>

          <div className="rounded-lg border border-base-300 bg-base-100 p-3">
            <p className="text-xs uppercase tracking-wide text-base-content/60">
              Start route
            </p>
            <p className="mt-1 text-base font-medium">
              {route?.start_terminal_id?.terminal_name}
            </p>
          </div>
          <div className="rounded-lg border border-base-300 bg-base-100 p-3">
            <p className="text-xs uppercase tracking-wide text-base-content/60">
              End route
            </p>
            <p className="mt-1 text-base font-medium">
              {route?.end_terminal_id?.terminal_name}
            </p>
          </div>

          <div className="rounded-lg border border-base-300 bg-base-100 p-3">
            <p className="text-xs uppercase tracking-wide text-base-content/60">
              ETA
            </p>
            <p className="mt-1 text-base font-medium">
              {formatEtaMinutes(route?.estimated_duration)}
            </p>
            <p className="mt-0.5 text-xs text-base-content/60">
              Estimated full-route duration
            </p>
          </div>
          <div className="rounded-lg border border-base-300 bg-base-100 p-3">
            <p className="text-xs uppercase tracking-wide text-base-content/60">
              Last updated
            </p>
            <p className="mt-1 text-base font-medium">
              {formatTimeAgo(route?.updatedAt ?? "")}
            </p>
          </div>
        </div>

        <RouteStops
          routeId={routeId}
          routeMongoId={route?._id}
          onToast={setToast}
        />
      </div>
    </div>
  );
}
