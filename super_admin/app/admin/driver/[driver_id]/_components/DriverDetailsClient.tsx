"use client";

import Link from "next/link";
import Image from "next/image";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import {
  FaArrowLeft,
  FaUser,
  FaIdCard,
  FaPhone,
  FaGaugeHigh,
  FaBus,
  FaRoute,
  FaTrash,
} from "react-icons/fa6";
import type { DriverProps } from "../../_components/drivers/DriverProps";
import type {
  AssignmentProps,
  AssignmentStatus,
  AssignmentResult,
} from "../../_components/assignmens/AssignmentProps";
import { useGetDriverDetails } from "../../_hooks/useGetDriverDetails";
import { useGetBusAssignments } from "../../_hooks/useGetBusAssignments";
import { useDeleteDriver } from "../_hooks/useDeleteDriver";
import {
  mapApiDriverToProps,
  mapApiBusAssignmentToProps,
  type ApiDriver,
  type ApiBusAssignmentRow,
} from "../../_lib/apiMappers";

const DELETE_DRIVER_CONFIRM_MODAL_ID = "delete-driver-confirm-modal";

function DriverStatusBadge({ status }: { status: string }) {
  const map: Record<string, string> = {
    active: "badge-success",
    inactive: "badge-ghost",
  };
  return (
    <span className={`badge badge-lg ${map[status] ?? "badge-ghost"}`}>
      {status}
    </span>
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
      <span
        className={`badge badge-lg ${resultClass[assignmentResult] ?? "badge-ghost"}`}
      >
        {assignmentResult}
      </span>
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
      {children !== undefined ? (
        children
      ) : (
        <span className="text-base font-medium">{value}</span>
      )}
    </div>
  );
}

type DriverDetailsClientProps = {
  driverId: string;
};

function resolveDriverProfileImage(profileImage?: string): string {
  const fallback = "/default-img.jpg";
  if (!profileImage || profileImage === "default.png") return fallback;
  if (/^https?:\/\//i.test(profileImage)) return profileImage;

  const baseUrl = (process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:4000").replace(
    /\/$/,
    "",
  );
  const normalized = profileImage
    .replace(/\\/g, "/")
    .replace(/^\/+/, "")
    .replace(/^server\//, "");

  if (normalized.startsWith("images/")) {
    return `${baseUrl}/${normalized}`;
  }

  return `${baseUrl}/images/driver/${normalized}`;
}

function assignmentSortTime(a: AssignmentProps): number {
  const raw = a.updatedAt ?? a.createdAt;
  if (!raw) return 0;
  const t = Date.parse(raw);
  return Number.isNaN(t) ? 0 : t;
}

function pickLatestAssignment(forDriver: AssignmentProps[]): AssignmentProps | null {
  if (forDriver.length === 0) return null;
  return forDriver.reduce((best, cur) => {
    const tb = assignmentSortTime(best);
    const tc = assignmentSortTime(cur);
    if (tc > tb) return cur;
    if (tc < tb) return best;
    return cur.id > best.id ? cur : best;
  });
}

export default function DriverDetailsClient({ driverId }: DriverDetailsClientProps) {
  const router = useRouter();
  const { getDriverDetails, error: driverHookError } = useGetDriverDetails();
  const { getBusAssignments, error: assignmentsHookError } = useGetBusAssignments();
  const { deleteDriver, error: deleteHookError } = useDeleteDriver();
  const [driver, setDriver] = useState<DriverProps | null>(null);
  const [latestAssignment, setLatestAssignment] = useState<AssignmentProps | null>(null);
  const [loading, setLoading] = useState(true);
  const [isDeleting, setIsDeleting] = useState(false);
  const [deleteError, setDeleteError] = useState<string | null>(null);
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const deleteDialogRef = useRef<HTMLDialogElement>(null);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      setLoading(true);
      const [driverRes, assignmentsRes] = await Promise.all([
        getDriverDetails(driverId),
        getBusAssignments(),
      ]);
      if (cancelled) return;

      if (driverRes?.success === true && driverRes.data) {
        setDriver(mapApiDriverToProps(driverRes.data as ApiDriver));
      } else {
        setDriver(null);
      }

      if (assignmentsRes?.success === true && Array.isArray(assignmentsRes.data)) {
        const mapped = (assignmentsRes.data as ApiBusAssignmentRow[]).map(
          mapApiBusAssignmentToProps,
        );
        const forDriver = mapped.filter((a) => a.driver_id === driverId);
        setLatestAssignment(pickLatestAssignment(forDriver));
      } else {
        setLatestAssignment(null);
      }

      setLoading(false);
    })();
    return () => {
      cancelled = true;
    };
  }, [driverId, getDriverDetails, getBusAssignments]);

  useEffect(() => {
    const el = deleteDialogRef.current;
    if (!el) return;
    if (showDeleteModal) {
      el.showModal();
    } else {
      el.close();
    }
  }, [showDeleteModal]);

  useEffect(() => {
    const el = deleteDialogRef.current;
    if (!el) return;
    const onClose = () => setShowDeleteModal(false);
    el.addEventListener("close", onClose);
    return () => el.removeEventListener("close", onClose);
  }, []);

  const profileImageSrc = resolveDriverProfileImage(driver?.profile_image);
  const [imageSrc, setImageSrc] = useState(profileImageSrc);

  useEffect(() => {
    setImageSrc(profileImageSrc);
  }, [profileImageSrc]);

  if (loading) {
    return (
      <div className="flex flex-col items-center justify-center gap-4 py-24">
        <span className="loading loading-spinner loading-lg text-primary" />
        <p className="text-base-content/70">Loading driver details…</p>
      </div>
    );
  }

  if (!driver) {
    return (
      <div className="space-y-6 pt-6">
        <Link
          href="/admin/driver"
          className="btn btn-ghost btn-sm gap-2"
          aria-label="Back to drivers"
        >
          <FaArrowLeft className="h-4 w-4" />
          Back to drivers
        </Link>
        <div role="alert" className="alert alert-error text-sm">
          <span>{driverHookError ?? "Could not load driver details."}</span>
        </div>
      </div>
    );
  }

  const fullName = `${driver.f_name} ${driver.l_name}`;

  async function handleConfirmDelete() {
    setIsDeleting(true);
    setDeleteError(null);
    try {
      const response = await deleteDriver(driverId);
      if (!response?.success) {
        setDeleteError(deleteHookError ?? response?.message ?? "Failed to delete driver");
        setIsDeleting(false);
        return;
      }
      setShowDeleteModal(false);
      router.push("/admin/driver");
      router.refresh();
    } catch {
      setDeleteError("Failed to delete driver");
      setIsDeleting(false);
    }
  }

  return (
    <div className="space-y-8 pt-6">
      <div className="relative overflow-hidden rounded-2xl bg-linear-to-br from-primary/15 via-base-100 to-base-100 border border-base-content/5 p-6 shadow-lg">
        <div className="absolute right-16 top-1/2 -translate-y-1/2 opacity-10">
          <FaUser className="h-32 w-32 text-primary" />
        </div>
        <div className="relative flex flex-wrap items-center justify-between gap-4">
          <div className="flex items-center gap-4">
            <Link
              href="/admin/driver"
              className="btn btn-ghost btn-sm btn-square hover:scale-110 transition-all duration-200 rounded-xl"
              aria-label="Back to drivers"
            >
              <FaArrowLeft className="w-8 h-8" />
            </Link>
            <div className="flex items-center gap-4">
              <div className="h-24 w-24 overflow-hidden rounded-xl border border-base-content/10 bg-base-200">
                <Image
                  src={imageSrc}
                  alt={`${fullName} profile`}
                  width={96}
                  height={96}
                  className="h-full w-full object-cover"
                  unoptimized
                  loading="eager"
                  onError={() => setImageSrc("/default-img.jpg")}
                />
              </div>
              <div>
                <h1 className="text-3xl font-bold tracking-tight">{fullName}</h1>
                <p className="text-base text-base-content/60 mt-0.5">
                  License: {driver.license_number} · ID: {driver.id}
                </p>
              </div>
            </div>
          </div>
          <DriverStatusBadge status={driver.status} />
        </div>
        <div className="relative mt-4 flex justify-end">
          <button
            type="button"
            onClick={() => {
              setDeleteError(null);
              setShowDeleteModal(true);
            }}
            disabled={isDeleting}
            className="btn bg-[#D0393A] hover:bg-[#D0393A]/80 gap-2 text-white rounded-xl btn-md text-base"
            aria-label={`Delete driver ${fullName}`}
          >
            <FaTrash className="w-4 h-4" />
            {isDeleting ? "Deleting…" : "Delete driver"}
          </button>
        </div>
      </div>

      {assignmentsHookError ? (
        <div role="alert" className="alert alert-warning text-sm">
          <span>Assignments could not be loaded: {assignmentsHookError}</span>
        </div>
      ) : null}

      <div className="grid gap-6 md:grid-cols-2">
        <div className="group rounded-2xl border border-base-content/5 bg-base-100 p-5 shadow-md shadow-base-content/5 transition-shadow hover:shadow-lg">
          <div className="mb-4 flex items-center gap-3 border-b border-base-content/10 pb-4">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-primary/10 text-primary">
              <FaIdCard className="h-5 w-5" />
            </div>
            <h2 className="text-xl font-semibold">Identification</h2>
          </div>
          <div className="space-y-0">
            <InfoRow label="First name" value={driver.f_name} />
            <InfoRow label="Last name" value={driver.l_name} />
            <InfoRow label="License number">
              <span className="rounded-lg bg-base-200 px-3 py-1.5 font-mono text-base font-semibold tracking-wider">
                {driver.license_number}
              </span>
            </InfoRow>
          </div>
        </div>

        <div className="group rounded-2xl border border-base-content/5 bg-base-100 p-5 shadow-md shadow-base-content/5 transition-shadow hover:shadow-lg">
          <div className="mb-4 flex items-center gap-3 border-b border-base-content/10 pb-4">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-secondary/15 text-secondary">
              <FaGaugeHigh className="h-5 w-5" />
            </div>
            <h2 className="text-xl font-semibold">Status & Contact</h2>
          </div>
          <div className="space-y-0">
            <InfoRow label="Driver status">
              <DriverStatusBadge status={driver.status} />
            </InfoRow>
            <InfoRow label="Contact number">
              <span className="flex items-center gap-2">
                {driver.contact_number ? (
                  <>
                    <FaPhone className="h-4 w-4 text-base-content/60" />
                    <span className="font-medium">{driver.contact_number}</span>
                  </>
                ) : (
                  <span className="text-base-content/50">—</span>
                )}
              </span>
            </InfoRow>
          </div>
        </div>

        <div className="group rounded-2xl border border-base-content/5 bg-base-100 p-5 shadow-md shadow-base-content/5 transition-shadow hover:shadow-lg md:col-span-2">
          <div className="mb-4 flex items-center gap-3 border-b border-base-content/10 pb-4">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-accent/20 text-accent">
              <FaBus className="h-5 w-5" />
            </div>
            <h2 className="text-xl font-semibold">Latest assignment</h2>
          </div>
          {!latestAssignment ? (
            <p className="text-base-content/60 py-4">No assignments for this driver.</p>
          ) : (
            <Link
              href={`/admin/driver/assignment/${latestAssignment.id}`}
              className="block rounded-xl border border-base-content/5 bg-base-200/50 p-4 transition-colors hover:bg-base-200/80"
            >
              <div className="flex flex-wrap items-center justify-between gap-3">
                <div className="flex items-center gap-3">
                  <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-primary/10 text-primary">
                    <FaRoute className="h-5 w-5" />
                  </div>
                  <div>
                    <p className="font-medium">
                      {latestAssignment.bus_number} · {latestAssignment.route_name}
                    </p>
                    <p className="text-sm text-base-content/60">
                      {latestAssignment.arrival_status} · {latestAssignment.departure_status}
                    </p>
                  </div>
                </div>
                <AssignmentBadge
                  assignmentStatus={latestAssignment.assignment_status}
                  assignmentResult={latestAssignment.assignment_result}
                />
              </div>
            </Link>
          )}
        </div>
      </div>

      <dialog
        ref={deleteDialogRef}
        id={DELETE_DRIVER_CONFIRM_MODAL_ID}
        className="modal"
        aria-labelledby="delete-driver-confirm-title"
        aria-describedby="delete-driver-confirm-desc"
      >
        <div className="modal-box">
          <h3 id="delete-driver-confirm-title" className="font-bold text-lg">
            Delete driver?
          </h3>
          <p id="delete-driver-confirm-desc" className="py-4 text-base-content/80">
            Are you sure you want to delete <strong>{fullName}</strong> (License{" "}
            <strong>{driver.license_number}</strong>)? This action cannot be undone.
          </p>
          {deleteError || deleteHookError ? (
            <div role="alert" className="alert alert-error mb-3 text-sm">
              <span>{deleteError ?? deleteHookError}</span>
            </div>
          ) : null}
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
              onClick={handleConfirmDelete}
              disabled={isDeleting}
            >
              <FaTrash className="w-4 h-4" />
              {isDeleting ? "Deleting…" : "Delete driver"}
            </button>
          </div>
        </div>
        <form method="dialog" className="modal-backdrop">
          <button type="submit" tabIndex={-1} aria-hidden>
            close
          </button>
        </form>
      </dialog>
    </div>
  );
}
