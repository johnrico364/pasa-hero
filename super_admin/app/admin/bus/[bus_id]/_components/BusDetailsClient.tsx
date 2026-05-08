"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import {
  FaArrowLeft,
  FaBus,
  FaIdCard,
  FaGaugeHigh,
  FaUser,
  FaRoute,
  FaTrash,
} from "react-icons/fa6";
import type { BusProps, AssignmentStatus, AssignmentResult } from "../../BusProps";
import { mapApiBusToBusProps, type ApiBus } from "../../mapApiBus";
import { useGetBusDetails } from "../../_hooks/useGetBusDetails";
import { useDeleteBus } from "../_hooks/useDeleteBus";

function BusStatusBadge({ status }: { status: string }) {
  const map: Record<string, string> = {
    active: "badge-success",
    maintenance: "badge-warning",
    "out of service": "badge-error",
  };
  return (
    <span className={`badge badge-lg ${map[status] ?? "badge-ghost"}`}>{status}</span>
  );
}

function OccupancyBadge({ status }: { status: string }) {
  const map: Record<string, string> = {
    empty: "badge-ghost",
    "few seats": "badge-info",
    "standing room": "badge-warning",
    full: "badge-error",
  };
  return (
    <span className={`badge badge-lg ${map[status] ?? "badge-ghost"}`}>{status}</span>
  );
}

function AssignmentBadge({
  assignmentStatus,
  assignmentResult,
}: {
  assignmentStatus: AssignmentStatus;
  assignmentResult: AssignmentResult;
}) {
  const statusClass: Record<string, string> = {
    active: "badge-success",
    inactive: "badge-ghost",
  };
  const resultClass: Record<string, string> = {
    pending: "badge-warning",
    completed: "badge-success",
    cancelled: "badge-error",
  };
  return (
    <span className="flex flex-wrap gap-2">
      <span
        className={`badge badge-lg ${statusClass[assignmentStatus] ?? "badge-ghost"}`}
      >
        {assignmentStatus}
      </span>
      {assignmentStatus === "active" ? (
        <span
          className={`badge badge-lg ${resultClass[assignmentResult] ?? "badge-ghost"}`}
        >
          {assignmentResult}
        </span>
      ) : null}
    </span>
  );
}

function InfoRow({
  label,
  value,
  children,
}: {
  label: string;
  value?: React.ReactNode;
  children?: React.ReactNode;
}) {
  return (
    <div className="flex flex-wrap items-baseline justify-between gap-2 py-3 border-b border-base-content/5 last:border-0">
      <span className="text-base font-medium text-base-content/70">{label}</span>
      {children !== undefined ? children : <span className="text-base font-medium">{value}</span>}
    </div>
  );
}

type BusDetailsClientProps = {
  busId: string;
};

export default function BusDetailsClient({ busId }: BusDetailsClientProps) {
  const router = useRouter();
  const { getBusDetails, error: hookError } = useGetBusDetails();
  const { deleteBus, error: deleteError } = useDeleteBus();
  const [bus, setBus] = useState<BusProps | null>(null);
  const [removedOrMissing, setRemovedOrMissing] = useState(false);
  const [loading, setLoading] = useState(true);
  const [isDeleting, setIsDeleting] = useState(false);
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const dialogRef = useRef<HTMLDialogElement>(null);

  useEffect(() => {
    const el = dialogRef.current;
    if (!el) return;
    if (showDeleteModal) {
      el.showModal();
    } else {
      el.close();
    }
  }, [showDeleteModal]);

  useEffect(() => {
    const el = dialogRef.current;
    if (!el) return;
    const onClose = () => setShowDeleteModal(false);
    el.addEventListener("close", onClose);
    return () => el.removeEventListener("close", onClose);
  }, []);

  const handleDelete = async () => {
    if (!bus || isDeleting) return;
    setIsDeleting(true);
    const response = await deleteBus(busId);

    if (response?.success === true) {
      setShowDeleteModal(false);
      router.push("/admin/bus");
      router.refresh();
      return;
    }

    setIsDeleting(false);
  };

  useEffect(() => {
    let cancelled = false;
    (async () => {
      setLoading(true);
      setRemovedOrMissing(false);
      const res = await getBusDetails(busId);
      if (cancelled) return;
      if (res?.success === true && res.data) {
        const raw = res.data as ApiBus;
        if (raw.is_deleted) {
          setRemovedOrMissing(true);
          setBus(null);
        } else {
          setBus(mapApiBusToBusProps(raw));
        }
      } else {
        setBus(null);
        setRemovedOrMissing(false);
      }
      setLoading(false);
    })();
    return () => {
      cancelled = true;
    };
  }, [busId, getBusDetails]);

  if (loading) {
    return (
      <div className="flex flex-col items-center justify-center gap-4 py-24">
        <span className="loading loading-spinner loading-lg text-primary" />
        <p className="text-base-content/70">Loading bus details…</p>
      </div>
    );
  }

  if (!bus) {
    const message = removedOrMissing
      ? "This bus was not found or has been removed."
      : hookError ?? "Could not load bus details.";
    return (
      <div className="space-y-6 pt-6">
        <Link
          href="/admin/bus"
          className="btn btn-ghost btn-sm gap-2"
          aria-label="Back to buses"
        >
          <FaArrowLeft className="h-4 w-4" />
          Back to buses
        </Link>
        <div
          role="alert"
          className={`alert text-sm ${removedOrMissing ? "alert-warning" : "alert-error"}`}
        >
          <span>{message}</span>
        </div>
      </div>
    );
  }

  const occupancyPercent =
    bus.capacity > 0 ? Math.round((bus.occupancy_count / bus.capacity) * 100) : 0;

  return (
    <div className="space-y-8 pt-6">
      <div className="relative overflow-hidden rounded-2xl bg-linear-to-br from-[#0062CA]/15 via-base-100 to-base-100 border border-base-content/5 p-6 shadow-lg">
        <div className="absolute right-4 top-1/2 -translate-y-1/2 opacity-10">
          <FaBus className="h-32 w-32 text-[#0062CA]" />
        </div>
        <div className="relative flex flex-wrap items-center justify-between gap-4">
          <div className="flex items-center gap-4">
            <Link
              href="/admin/bus"
              className="btn btn-ghost btn-sm btn-square hover:scale-110 transition-all duration-200 rounded-xl"
              aria-label="Back to buses"
            >
              <FaArrowLeft className="w-7 h-7" />
            </Link>
            <div className="flex items-center gap-4">
              <div className="flex h-14 w-14 items-center justify-center rounded-xl bg-[#0062CA]/20 text-[#0062CA]">
                <FaBus className="h-7 w-7" />
              </div>
              <div>
                <h1 className="text-3xl font-bold tracking-tight">Bus {bus.bus_number}</h1>
                <p className="text-base text-base-content/60 mt-0.5">
                  Plate: {bus.plate_number} · ID: {bus.id}
                </p>
              </div>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <BusStatusBadge status={bus.bus_status} />
            <OccupancyBadge status={bus.occupancy_status} />
            <button
              type="button"
              onClick={() => setShowDeleteModal(true)}
              disabled={isDeleting}
              className="btn bg-[#D0393A] hover:bg-[#D0393A]/80 gap-2 text-white rounded-xl btn-md text-base disabled:cursor-not-allowed disabled:opacity-70"
              aria-label={`Delete bus ${bus.bus_number}`}
            >
              <FaTrash className="w-4 h-4" />
              {isDeleting ? "Deleting..." : "Delete"}
            </button>
          </div>
        </div>
      </div>
      {deleteError ? (
        <div role="alert" className="alert alert-error text-sm">
          <span>{deleteError}</span>
        </div>
      ) : null}
      <dialog
        ref={dialogRef}
        className="modal"
        aria-labelledby="delete-bus-confirm-title"
        aria-describedby="delete-bus-confirm-desc"
      >
        <div className="modal-box">
          <h3 id="delete-bus-confirm-title" className="font-bold text-lg">
            Delete bus?
          </h3>
          <p id="delete-bus-confirm-desc" className="py-4 text-base-content/80">
            Are you sure you want to delete <strong>Bus {bus.bus_number}</strong>? This action
            cannot be undone.
          </p>
          <div className="modal-action">
            <button
              type="button"
              className="btn btn-ghost"
              onClick={() => setShowDeleteModal(false)}
              disabled={isDeleting}
            >
              Cancel
            </button>
            <button
              type="button"
              className="btn bg-[#D0393A] hover:bg-[#D0393A]/80 gap-2 text-white"
              onClick={handleDelete}
              disabled={isDeleting}
            >
              <FaTrash className="w-4 h-4" />
              {isDeleting ? "Deleting..." : "Delete bus"}
            </button>
          </div>
        </div>
        <form method="dialog" className="modal-backdrop">
          <button type="submit" tabIndex={-1} aria-hidden>
            close
          </button>
        </form>
      </dialog>

      <div className="grid gap-6 md:grid-cols-2">
        <div className="group rounded-2xl border border-base-content/5 bg-base-100 p-5 shadow-md shadow-base-content/5 transition-shadow hover:shadow-lg">
          <div className="mb-4 flex items-center gap-3 border-b border-base-content/10 pb-4">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-primary/10 text-primary">
              <FaIdCard className="h-5 w-5" />
            </div>
            <h2 className="text-xl font-semibold">Identification</h2>
          </div>
          <div className="space-y-0">
            <InfoRow label="Bus number" value={bus.bus_number} />
            <InfoRow label="Plate number">
              <span className="rounded-lg bg-base-200 px-3 py-1.5 font-mono text-base font-semibold tracking-wider">
                {bus.plate_number}
              </span>
            </InfoRow>
            <InfoRow label="Maximum capacity" value={`${bus.capacity} seats`} />
          </div>
        </div>

        <div className="group rounded-2xl border border-base-content/5 bg-base-100 p-5 shadow-md shadow-base-content/5 transition-shadow hover:shadow-lg">
          <div className="mb-4 flex items-center gap-3 border-b border-base-content/10 pb-4">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-secondary/15 text-secondary">
              <FaGaugeHigh className="h-5 w-5" />
            </div>
            <h2 className="text-xl font-semibold">Status</h2>
          </div>
          <div className="space-y-0">
            <InfoRow label="Bus status">
              <BusStatusBadge status={bus.bus_status} />
            </InfoRow>
            <InfoRow label="Occupancy status">
              <OccupancyBadge status={bus.occupancy_status} />
            </InfoRow>
            <InfoRow label="Occupancy" value={`${bus.occupancy_count} / ${bus.capacity} passengers`} />
            <div className="pt-3">
              <div className="flex justify-between text-base-content/70 mb-1">
                <span>Seats filled</span>
                <span className="font-medium">{occupancyPercent}%</span>
              </div>
              <progress
                className="progress progress-primary h-4 w-full"
                value={occupancyPercent}
                max={100}
              />
            </div>
          </div>
        </div>

        <div className="group rounded-2xl border border-base-content/5 bg-base-100 p-5 shadow-md shadow-base-content/5 transition-shadow hover:shadow-lg md:col-span-2">
          <div className="mb-4 flex items-center gap-3 border-b border-base-content/10 pb-4">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-accent/20 text-accent">
              <FaUser className="h-5 w-5" />
            </div>
            <h2 className="text-xl font-semibold">Assignment</h2>
          </div>
          <div className="grid gap-6 sm:grid-cols-2">
            <div className="space-y-0 rounded-xl bg-base-200/50 p-4">
              <div className="mb-3 flex items-center gap-2 text-base-content/70">
                <FaUser className="h-4 w-4" />
                <span className="text-sm font-medium uppercase tracking-wide">Driver &amp; Route</span>
              </div>
              <InfoRow label="Driver" value={bus.driver_name} />
              <InfoRow label="Route name" value={bus.route_name} />
              <InfoRow label="Route code" value={bus.route_code} />
            </div>
            <div className="flex flex-col justify-center rounded-xl bg-base-200/50 p-4">
              <div className="mb-3 flex items-center gap-2 text-base-content/70">
                <FaRoute className="h-4 w-4" />
                <span className="text-sm font-medium uppercase tracking-wide">Assignment</span>
              </div>
              <InfoRow label="Assignment status">
                <AssignmentBadge
                  assignmentStatus={bus.assignment_status}
                  assignmentResult={bus.assignment_result}
                />
              </InfoRow>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
