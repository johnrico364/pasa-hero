"use client";

import { useEffect, useRef, useState } from "react";
import { GoogleMap, useJsApiLoader } from "@react-google-maps/api";
import { googleMapsApiKey, isGoogleMapsConfigured } from "@/lib/firebaseClient";
import {
  GOOGLE_MAPS_LIBRARIES,
  GOOGLE_MAPS_SCRIPT_ID,
} from "@/lib/googleMaps";

type RouteStopRow = {
  id: string;
  stopName: string;
  stopOrder: number;
  latitude: number;
  longitude: number;
};

type AddBusStopProps = {
  routeId: string | null | undefined;
  activeStops: RouteStopRow[];
  onAddStop: (payload: {
    stopName: string;
    latitude: number;
    longitude: number;
  }) => Promise<{ ok: boolean; message: string }>;
  onToast: (message: string) => void;
};

const DEFAULT_MAP_ZOOM = 14.5;

/** Default map pin / center when no prior stop on the route (Mandaue City, Cebu). */
const DEFAULT_FOCUS_LAT = 10.3237;
const DEFAULT_FOCUS_LNG = 123.9223;

export default function AddBusStop({ routeId, activeStops, onAddStop, onToast }: AddBusStopProps) {
  const [openAddStopModal, setOpenAddStopModal] = useState(false);
  const [newStopName, setNewStopName] = useState("");
  const [newStopLatitude, setNewStopLatitude] = useState<number>(DEFAULT_FOCUS_LAT);
  const [newStopLongitude, setNewStopLongitude] = useState<number>(DEFAULT_FOCUS_LNG);
  const [mapInstance, setMapInstance] = useState<google.maps.Map | null>(null);
  const markerRef = useRef<google.maps.marker.AdvancedMarkerElement | null>(null);
  const addStopDialogRef = useRef<HTMLDialogElement>(null);
  const { isLoaded: isGoogleMapsLoaded, loadError: googleMapsLoadError } = useJsApiLoader({
    id: GOOGLE_MAPS_SCRIPT_ID,
    googleMapsApiKey: isGoogleMapsConfigured ? googleMapsApiKey : "",
    libraries: GOOGLE_MAPS_LIBRARIES,
  });

  useEffect(() => {
    const dialog = addStopDialogRef.current;
    if (!dialog) return;
    if (openAddStopModal) dialog.showModal();
    else dialog.close();

    const onClose = () => setOpenAddStopModal(false);
    dialog.addEventListener("close", onClose);
    return () => dialog.removeEventListener("close", onClose);
  }, [openAddStopModal]);

  function onOpenAddStopModal() {
    if (!routeId) return;
    const last = activeStops[activeStops.length - 1];
    setNewStopName("");
    setNewStopLatitude(last?.latitude ?? DEFAULT_FOCUS_LAT);
    setNewStopLongitude(last?.longitude ?? DEFAULT_FOCUS_LNG);
    setOpenAddStopModal(true);
  }

  function setCoordinateSelection(latitude: number, longitude: number) {
    const roundedLatitude = Number(latitude.toFixed(6));
    const roundedLongitude = Number(longitude.toFixed(6));
    setNewStopLatitude(roundedLatitude);
    setNewStopLongitude(roundedLongitude);
    console.log(
      `[AddBusStop] longitude=${roundedLongitude}, latitude=${roundedLatitude}`,
    );
  }

  function onMapClick(event: google.maps.MapMouseEvent) {
    if (!event.latLng) return;
    setCoordinateSelection(event.latLng.lat(), event.latLng.lng());
  }

  useEffect(() => {
    if (!openAddStopModal || !mapInstance || !window.google?.maps) return;
    window.google.maps.event.trigger(mapInstance, "resize");
    mapInstance.setCenter({ lat: newStopLatitude, lng: newStopLongitude });
  }, [openAddStopModal, mapInstance, newStopLatitude, newStopLongitude]);

  useEffect(() => {
    if (!mapInstance || !window.google?.maps?.marker?.AdvancedMarkerElement) return;
    if (markerRef.current) markerRef.current.map = null;

    markerRef.current = new google.maps.marker.AdvancedMarkerElement({
      map: mapInstance,
      position: { lat: newStopLatitude, lng: newStopLongitude },
      title: `Bus stop (${newStopLatitude.toFixed(6)}, ${newStopLongitude.toFixed(6)})`,
    });

    return () => {
      if (markerRef.current) markerRef.current.map = null;
      markerRef.current = null;
    };
  }, [mapInstance, newStopLatitude, newStopLongitude]);

  async function onSubmitAddStop() {
    const stopName = newStopName.trim();
    if (!stopName) {
      onToast("Please enter a stop name.");
      return;
    }
    if (!Number.isFinite(newStopLatitude) || !Number.isFinite(newStopLongitude)) {
      onToast("Please select a valid location on the map.");
      return;
    }

    const result = await onAddStop({
      stopName,
      latitude: Number(newStopLatitude.toFixed(6)),
      longitude: Number(newStopLongitude.toFixed(6)),
    });
    onToast(result.message);
    if (!result.ok) return;
    setNewStopName("");
    setOpenAddStopModal(false);
  }

  return (
    <>
      <div className="mb-4">
        <button type="button" className="btn btn-outline" onClick={onOpenAddStopModal}>
          Add route stop
        </button>
      </div>

      <dialog ref={addStopDialogRef} className="modal">
        <div className="modal-box w-11/12 max-w-4xl">
          <h3 className="text-xl font-bold">Add route stop</h3>
          <p className="mt-1 text-sm text-base-content/70">
            Enter the stop name and pick location from the map.
          </p>

          <div className="mt-4 space-y-3">
            <label className="form-control w-full">
              <span className="label-text font-medium">Route stop name</span>
              <input
                type="text"
                className="input input-bordered w-full"
                placeholder="e.g. Quezon Avenue"
                value={newStopName}
                onChange={(e) => setNewStopName(e.target.value)}
              />
            </label>

            <div className="rounded-lg border border-base-300 p-3">
              <p className="mb-2 text-sm font-medium">Map picker</p>
              <div className="relative h-96 w-full overflow-hidden rounded-md border border-base-300 bg-base-200">
                {isGoogleMapsConfigured ? (
                  googleMapsLoadError ? (
                    <div className="flex h-full items-center justify-center px-6 text-center text-sm text-error">
                      Failed to load Google Maps script. Check your API key and map restrictions.
                    </div>
                  ) : isGoogleMapsLoaded ? (
                    <GoogleMap
                      center={{ lat: newStopLatitude, lng: newStopLongitude }}
                      zoom={DEFAULT_MAP_ZOOM}
                      mapContainerStyle={{ width: "100%", height: "100%" }}
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
                    <div className="flex h-full items-center justify-center px-6 text-center text-sm text-base-content/70">
                      Loading map...
                    </div>
                  )
                ) : (
                  <div className="flex h-full items-center justify-center px-6 text-center text-sm text-base-content/70">
                    Add <code className="mx-1">NEXT_PUBLIC_GOOGLE_MAPS_API_KEY</code> to show Google Map
                    preview.
                  </div>
                )}
              </div>
              <p className="mt-2 text-xs text-base-content/70">
                Click anywhere on the map to set the stop coordinates.
              </p>
            </div>

            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              <label className="form-control w-full">
                <span className="label-text text-sm font-medium">Latitude</span>
                <input
                  type="number"
                  step="0.000001"
                  className="input input-bordered w-full"
                  value={newStopLatitude}
                  onChange={(e) =>
                    setCoordinateSelection(Number(e.target.value), newStopLongitude)
                  }
                />
              </label>
              <label className="form-control w-full">
                <span className="label-text text-sm font-medium">Longitude</span>
                <input
                  type="number"
                  step="0.000001"
                  className="input input-bordered w-full"
                  value={newStopLongitude}
                  onChange={(e) =>
                    setCoordinateSelection(newStopLatitude, Number(e.target.value))
                  }
                />
              </label>
            </div>
          </div>

          <div className="modal-action flex-wrap gap-2">
            <button type="button" className="btn btn-ghost" onClick={() => setOpenAddStopModal(false)}>
              Cancel
            </button>
            <button
              type="button"
              className="btn bg-[#0062CA] text-white"
              onClick={() => void onSubmitAddStop()}
            >
              Add stop
            </button>
          </div>
        </div>
        <form method="dialog" className="modal-backdrop">
          <button type="submit" aria-label="Close">
            close
          </button>
        </form>
      </dialog>
    </>
  );
}
