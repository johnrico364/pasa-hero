"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { GoogleMap } from "@react-google-maps/api";

export type RouteStopsMapStop = {
  stop_name: string;
  stop_order: number;
  latitude: number;
  longitude: number;
};

const ROUTE_STOPS_MAP_ID = "DEMO_MAP_ID";
const ROUTE_STOPS_MAP_HEIGHT_PX = 440;
const ROUTE_STOPS_MAP_DEFAULT_CENTER = { lat: 10.3313, lng: 123.9362 };

type RouteStopsMapProps = {
  stops: RouteStopsMapStop[];
};

export default function RouteStopsMap({ stops }: RouteStopsMapProps) {
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
        Number.isFinite(Number(s.latitude)) &&
        Number.isFinite(Number(s.longitude)),
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
      Number.isFinite(Number(s.latitude)) &&
      Number.isFinite(Number(s.longitude)),
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
