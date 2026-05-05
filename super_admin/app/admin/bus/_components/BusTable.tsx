"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { BusProps, type BusAssignmentRow } from "../BusProps";
import EditBusModal from "./EditBus";
import { FaRegEye } from "react-icons/fa6";

function BusStatusBadge({ status }: { status: string }) {
  const map: Record<string, string> = {
    active: "badge-success",
    maintenance: "badge-warning",
    "out of service": "badge-error",
  };
  return (
    <span className={`badge badge-sm ${map[status] ?? "badge-ghost"}`}>{status}</span>
  );
}

function pickPrimaryAssignment(
  assignments: BusAssignmentRow[] | undefined,
): BusAssignmentRow | null {
  if (!assignments?.length) return null;
  const active = assignments.find((a) => a.assignment_status === "active");
  return active ?? assignments[0];
}

function personName(
  person:
    | { f_name?: string; l_name?: string }
    | string
    | null
    | undefined,
): string {
  if (!person || typeof person === "string") return "—";
  const parts = [person.f_name, person.l_name].filter(Boolean);
  return parts.length ? parts.join(" ") : "—";
}

function routeFromAssignment(
  route: BusAssignmentRow["route_id"],
): { route_name: string; route_code: string } {
  if (!route || typeof route === "string") {
    return { route_name: "—", route_code: "—" };
  }
  return {
    route_name: route.route_name ?? "—",
    route_code: route.route_code ?? "—",
  };
}

const DEFAULT_PAGE_SIZE = 10;

type BusTableProps = {
  buses: BusProps[];
  pageSize?: number;
  onBusUpdated?: () => void | Promise<void>;
};

export default function BusTable({
  buses,
  pageSize = DEFAULT_PAGE_SIZE,
  onBusUpdated,
}: BusTableProps) {
  const router = useRouter();
  const [page, setPage] = useState(1);

  const totalPages = Math.max(1, Math.ceil(buses.length / pageSize));
  const activePage = Math.min(Math.max(1, page), totalPages);

  const pageBuses = useMemo(() => {
    const start = (activePage - 1) * pageSize;
    return buses.slice(start, start + pageSize);
  }, [buses, activePage, pageSize]);

  const go = (next: number) => {
    setPage(Math.min(Math.max(1, next), totalPages));
  };

  const pageNumbers = useMemo(() => {
    const window = 2;
    const lo = Math.max(1, activePage - window);
    const hi = Math.min(totalPages, activePage + window);
    const nums: number[] = [];
    for (let p = lo; p <= hi; p++) nums.push(p);
    return nums;
  }, [activePage, totalPages]);

  return (
    <>
    <div className="overflow-x-auto rounded-box border border-base-content/5 bg-base-100">
      <table className="table">
        <thead>
          <tr>
            <th className="w-10">#</th>
            <th>Bus Number</th>
            <th>Plate #</th>
            <th>Capacity</th>
            <th>Bus status</th>
            <th>Driver</th>
            <th>Route</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {pageBuses.map((bus, i) => {
            const primary = pickPrimaryAssignment(bus.assignments);
            const driverDisplay = primary
              ? personName(primary.driver_id)
              : bus.driver_name;
            const routeDisplay = primary
              ? routeFromAssignment(primary.route_id)
              : {
                  route_name: bus.route_name,
                  route_code: bus.route_code,
                };

            return (
            <tr key={bus.id}>
              <th>{(activePage - 1) * pageSize + i + 1}</th>
              <td className="font-medium">{bus.bus_number}</td>
              <td>{bus.plate_number}</td>
              <td>{bus.capacity}</td>
              <td>
                <BusStatusBadge status={bus.bus_status} />
              </td>
              <td>{driverDisplay}</td>
              <td>
                <span className="font-medium">{routeDisplay.route_name}</span>
                <br />
                <span className="text-xs text-base-content/60">
                  {routeDisplay.route_code}
                </span>
              </td>
              <td className="flex gap-2">
                <button
                  className="btn btn-sm"
                  onClick={() => router.push(`/admin/bus/${bus.id}`)}
                >
                  <FaRegEye className="w-5 h-5" />
                  View
                </button>
                <EditBusModal bus={bus} onBusUpdated={onBusUpdated} />
              </td>
            </tr>
            );
          })}
        </tbody>
      </table>
    </div>

    {buses.length > 0 ? (
      <div className="flex flex-col items-stretch gap-3 border-t border-base-content/10 bg-base-100 px-4 py-3 sm:flex-row sm:items-center sm:justify-between">
        <p className="text-sm text-base-content/70">
          {(activePage - 1) * pageSize + 1}–
          {Math.min(activePage * pageSize, buses.length)} of {buses.length}
        </p>
        <div className="join flex-wrap justify-center">
          <button
            type="button"
            className="btn join-item btn-sm"
            disabled={activePage <= 1}
            onClick={() => go(1)}
          >
            First
          </button>
          <button
            type="button"
            className="btn join-item btn-sm"
            disabled={activePage <= 1}
            onClick={() => go(activePage - 1)}
          >
            Prev
          </button>
          {pageNumbers.map((p) => (
            <button
              key={p}
              type="button"
              className={`btn join-item btn-sm ${p === activePage ? "btn-active" : ""}`}
              onClick={() => go(p)}
            >
              {p}
            </button>
          ))}
          <button
            type="button"
            className="btn join-item btn-sm"
            disabled={activePage >= totalPages}
            onClick={() => go(activePage + 1)}
          >
            Next
          </button>
          <button
            type="button"
            className="btn join-item btn-sm"
            disabled={activePage >= totalPages}
            onClick={() => go(totalPages)}
          >
            Last
          </button>
        </div>
      </div>
    ) : null}
    </>
  );
}
