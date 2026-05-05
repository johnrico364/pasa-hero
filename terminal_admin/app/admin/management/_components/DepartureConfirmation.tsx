"use client";

import { useState } from "react";
import { useConfirmTerminalLog } from "../_hooks/useConfirmTerminalLog";
import { useRejectTerminalLog } from "../_hooks/useRejectTerminalLog";

type PendingDepartureRow = {
  id: string;
  busNumber: string;
  routeName: string;
  departureReportedAt: string | null;
};

type DepartureConfirmationProps = {
  pendingDepartures: PendingDepartureRow[];
  onConfirmDeparture?: (id: string) => void | Promise<void>;
  onConfirmToast?: (message: string) => void;
  onRejectDeparture: (id: string) => void;
};

function formatDateTime(iso: string) {
  return new Date(iso).toLocaleString([], {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export default function DepartureConfirmation({
  pendingDepartures,
  onConfirmDeparture,
  onConfirmToast,
  onRejectDeparture,
}: DepartureConfirmationProps) {
  const { confirmTerminalLog } = useConfirmTerminalLog();
  const { rejectTerminalLog } = useRejectTerminalLog();
  const [confirmingId, setConfirmingId] = useState<string | null>(null);
  const [rejectingId, setRejectingId] = useState<string | null>(null);
  const [lastError, setLastError] = useState<string | null>(null);

  const handleConfirm = async (terminalLogId: string) => {
    setConfirmingId(terminalLogId);
    setLastError(null);
    try {
      const res = await confirmTerminalLog(terminalLogId);
      if (
        res &&
        typeof res === "object" &&
        "success" in res &&
        res.success === true
      ) {
        await onConfirmDeparture?.(terminalLogId);
        const successMsg =
          "message" in res &&
          typeof (res as { message?: unknown }).message === "string"
            ? (res as { message: string }).message
            : "Departure confirmed";
        onConfirmToast?.(successMsg);
      } else {
        const msg =
          res &&
          typeof res === "object" &&
          "message" in res &&
          typeof (res as { message?: unknown }).message === "string"
            ? (res as { message: string }).message
            : "Could not confirm";
        setLastError(msg);
      }
    } finally {
      setConfirmingId(null);
    }
  };

  const handleReject = async (terminalLogId: string) => {
    setRejectingId(terminalLogId);
    setLastError(null);
    try {
      const res = await rejectTerminalLog(terminalLogId);
      if (
        res &&
        typeof res === "object" &&
        "success" in res &&
        res.success === true
      ) {
        await onRejectDeparture(terminalLogId);
        const successMsg =
          "message" in res &&
          typeof (res as { message?: unknown }).message === "string"
            ? (res as { message: string }).message
            : "Departure rejected";
        onConfirmToast?.(successMsg);
      } else {
        const msg =
          res &&
          typeof res === "object" &&
          "message" in res &&
          typeof (res as { message?: unknown }).message === "string"
            ? (res as { message: string }).message
            : "Could not reject";
        setLastError(msg);
      }
    } finally {
      setRejectingId(null);
    }
  };

  return (
    <div className="rounded-xl border-2 border-[#0062CA]/40 bg-base-100 p-4 shadow-sm ring-1 ring-[#0062CA]/20">
      <div className="mb-3 flex items-center justify-between">
        <h2 className="text-lg font-semibold">Pending departure confirmations</h2>
        <span className="badge bg-[#0062CA] text-white">{pendingDepartures.length}</span>
      </div>
      {lastError ? (
        <div className="alert alert-error mb-3 py-2 text-sm" role="alert">
          {lastError}
        </div>
      ) : null}
      <div className="overflow-x-auto min-h-40 max-h-80 rounded-lg border border-[#0062CA]/20">
        <table className="table table-zebra w-full">
          <thead className="bg-[#0062CA]/10">
            <tr>
              <th>Bus</th>
              <th>Route</th>
              <th>Reported at</th>
              <th className="text-right">Actions</th>
            </tr>
          </thead>
          <tbody>
            {pendingDepartures.length ? (
              pendingDepartures.map((row) => (
                <tr key={row.id}>
                  <td className="font-semibold">{row.busNumber}</td>
                  <td>{row.routeName}</td>
                  <td>{row.departureReportedAt ? formatDateTime(row.departureReportedAt) : "-"}</td>
                  <td className="text-right">
                    <div className="flex flex-wrap justify-end gap-2">
                      <button
                        type="button"
                        className={`btn btn-sm text-sm bg-[#0062CA] text-white ${confirmingId === row.id ? "loading" : ""}`}
                        disabled={confirmingId !== null || rejectingId !== null}
                        onClick={() => void handleConfirm(row.id)}
                      >
                        Confirm
                      </button>
                      <button
                        type="button"
                        className={`btn btn-sm text-sm btn-outline btn-error ${rejectingId === row.id ? "loading" : ""}`}
                        disabled={confirmingId !== null || rejectingId !== null}
                        onClick={() => void handleReject(row.id)}
                      >
                        Reject
                      </button>
                    </div>
                  </td>
                </tr>
              ))
            ) : (
              <tr>
                <td colSpan={4} className="text-center text-sm text-base-content/60">
                  No departure events waiting for confirmation.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
