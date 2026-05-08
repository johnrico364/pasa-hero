"use client";

import { useState, useMemo, useEffect, useCallback } from "react";
import {
  TerminalProps,
  TerminalLogProps,
  type TerminalStatus,
  type TerminalLogEventType,
  type TerminalLogStatus,
} from "./TerminalProps";
import TerminalTable from "./_components/TerminalTable";
import TerminalLogTable from "./_components/TerminalLogTable";
import AddTerminalModal from "./_components/AddTerminal";
import { useGetTerminals } from "./_hooks/useGetTerminals";
import { useGetTerminalLogs } from "./_hooks/useGetTerminalLogs";

type ApiTerminal = {
  _id: string;
  terminal_name: string;
  location_lat: number;
  location_lng: number;
  status?: string;
  createdAt?: string;
  updatedAt?: string;
};

type ApiTerminalLog = {
  _id: string;
  terminal_name: string | null;
  bus_number: string | null;
  event_type: string;
  status: string;
  event_time: string;
  confirmation_time: string | null;
};

function mapApiTerminalToProps(t: ApiTerminal): TerminalProps {
  const status: TerminalStatus = t.status === "inactive" ? "inactive" : "active";
  return {
    id: String(t._id),
    terminal_name: t.terminal_name,
    location_lat: Number(t.location_lat),
    location_lng: Number(t.location_lng),
    status,
    createdAt: t.createdAt,
    updatedAt: t.updatedAt,
  };
}

const TERMINAL_STATUS_OPTIONS: TerminalStatus[] = ["active", "inactive"];

function mapApiTerminalLogToProps(log: ApiTerminalLog): TerminalLogProps {
  const eventTypeMap: Record<string, TerminalLogEventType> = {
    arrival: "arrival",
    departure: "departure",
  };
  const statusMap: Record<string, TerminalLogStatus> = {
    pending: "pending",
    confirmed: "confirmed",
    rejected: "rejected",
  };
  return {
    id: String(log._id),
    terminal_id: "",
    bus_id: "",
    terminal_name: log.terminal_name ?? "Unknown terminal",
    bus_number: log.bus_number ?? "Unknown bus",
    event_type: eventTypeMap[log.event_type] ?? "arrival",
    status: statusMap[log.status] ?? "pending",
    event_time: log.event_time,
    confirmation_time: log.confirmation_time,
    auto_detected: false,
    remarks: null,
  };
}

const LOG_EVENT_TYPE_OPTIONS: TerminalLogEventType[] = [
  "arrival",
  "departure",
];
const LOG_STATUS_OPTIONS: TerminalLogStatus[] = [
  "pending",
  "confirmed",
  "rejected",
];
const LOGS_PER_PAGE = 10;

export default function Terminal() {
  const { getTerminals, error: terminalsError } = useGetTerminals();
  const { getTerminalLogs, error: terminalLogsError } = useGetTerminalLogs();
  const [terminals, setTerminals] = useState<TerminalProps[]>([]);
  const [terminalLogs, setTerminalLogs] = useState<TerminalLogProps[]>([]);
  const [terminalsLoading, setTerminalsLoading] = useState(true);
  const [terminalLogsLoading, setTerminalLogsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState<TerminalStatus | "all">("all");
  const [logSearchQuery, setLogSearchQuery] = useState("");
  const [logEventFilter, setLogEventFilter] = useState<
    TerminalLogEventType | "all"
  >("all");
  const [logStatusFilter, setLogStatusFilter] = useState<
    TerminalLogStatus | "all"
  >("all");
  const [logCurrentPage, setLogCurrentPage] = useState(1);

  const refetchTerminals = useCallback(async () => {
    setTerminalsLoading(true);
    const res = await getTerminals();
    if (res?.success === true && Array.isArray(res.data)) {
      setTerminals((res.data as ApiTerminal[]).map(mapApiTerminalToProps));
    } else {
      setTerminals([]);
    }
    setTerminalsLoading(false);
  }, [getTerminals]);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      setTerminalsLoading(true);
      const res = await getTerminals();
      if (cancelled) return;
      if (res?.success === true && Array.isArray(res.data)) {
        setTerminals((res.data as ApiTerminal[]).map(mapApiTerminalToProps));
      } else {
        setTerminals([]);
      }
      setTerminalsLoading(false);
    })();
    return () => {
      cancelled = true;
    };
  }, [getTerminals]);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      setTerminalLogsLoading(true);
      const res = await getTerminalLogs();
      if (cancelled) return;
      if (res?.success === true && Array.isArray(res.data)) {
        setTerminalLogs((res.data as ApiTerminalLog[]).map(mapApiTerminalLogToProps));
      } else {
        setTerminalLogs([]);
      }
      setTerminalLogsLoading(false);
    })();
    return () => {
      cancelled = true;
    };
  }, [getTerminalLogs]);

  const filteredTerminals = useMemo(() => {
    const q = searchQuery.trim().toLowerCase();
    return terminals.filter((t) => {
      const matchSearch =
        !q ||
        t.terminal_name.toLowerCase().includes(q) ||
        t.location_lat.toString().includes(q) ||
        t.location_lng.toString().includes(q);
      const matchStatus =
        statusFilter === "all" || t.status === statusFilter;
      return matchSearch && matchStatus;
    });
  }, [searchQuery, statusFilter, terminals]);

  const filteredLogs = useMemo(() => {
    const q = logSearchQuery.trim().toLowerCase();
    return terminalLogs.filter((log) => {
      const matchSearch =
        !q ||
        log.terminal_name.toLowerCase().includes(q) ||
        log.bus_number.toLowerCase().includes(q) ||
        log.event_type.toLowerCase().includes(q) ||
        (log.remarks && log.remarks.toLowerCase().includes(q));
      const matchEvent =
        logEventFilter === "all" || log.event_type === logEventFilter;
      const matchStatus =
        logStatusFilter === "all" || log.status === logStatusFilter;
      return matchSearch && matchEvent && matchStatus;
    });
  }, [logSearchQuery, logEventFilter, logStatusFilter, terminalLogs]);

  const logTotalPages = useMemo(
    () => Math.max(1, Math.ceil(filteredLogs.length / LOGS_PER_PAGE)),
    [filteredLogs.length],
  );

  const currentLogPage = Math.min(logCurrentPage, logTotalPages);

  const paginatedLogs = useMemo(() => {
    const start = (currentLogPage - 1) * LOGS_PER_PAGE;
    return filteredLogs.slice(start, start + LOGS_PER_PAGE);
  }, [filteredLogs, currentLogPage]);

  return (
    <div className="space-y-4 pt-6">
      {terminalsError ? (
        <div role="alert" className="alert alert-error text-sm">
          {terminalsError}
        </div>
      ) : null}
      {terminalLogsError ? (
        <div role="alert" className="alert alert-error text-sm">
          {terminalLogsError}
        </div>
      ) : null}
      <div className="text-xl font-bold">Terminal Management Table</div>
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div className="flex flex-wrap items-end gap-4">
          <div className="form-control w-64">
            <input
              type="text"
              placeholder="Search by name or coordinates..."
              className="input input-bordered w-full"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
            />
          </div>
          <div className="form-control w-40">
            <select
              className="select select-bordered w-full"
              value={statusFilter}
              onChange={(e) =>
                setStatusFilter(e.target.value as TerminalStatus | "all")
              }
            >
              <option value="all">All status</option>
              {TERMINAL_STATUS_OPTIONS.map((s) => (
                <option key={s} value={s}>
                  {s}
                </option>
              ))}
            </select>
          </div>
          <span className="text-sm text-base-content/70">
            Showing {filteredTerminals.length} of {terminals.length} terminals
          </span>
        </div>
        <AddTerminalModal onCreated={refetchTerminals} />
      </div>
      {terminalsLoading ? (
        <div className="flex justify-center py-16">
          <span className="loading loading-spinner loading-lg text-primary" />
        </div>
      ) : (
        <TerminalTable
          terminals={filteredTerminals}
          onTerminalUpdated={refetchTerminals}
        />
      )}
      <div className="text-xl font-bold mt-10">Terminal Logs</div>
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div className="flex flex-wrap items-end gap-4">
          <div className="form-control w-64">
            <input
              type="text"
              placeholder="Search terminal, bus, event..."
              className="input input-bordered w-full"
              value={logSearchQuery}
              onChange={(e) => {
                setLogSearchQuery(e.target.value);
                setLogCurrentPage(1);
              }}
            />
          </div>
          <div className="form-control w-44">
            <select
              className="select select-bordered w-full"
              value={logEventFilter}
              onChange={(e) => {
                setLogEventFilter(e.target.value as TerminalLogEventType | "all");
                setLogCurrentPage(1);
              }}
            >
              <option value="all">All events</option>
              {LOG_EVENT_TYPE_OPTIONS.map((e) => (
                <option key={e} value={e}>
                  {e.replace(/_/g, " ")}
                </option>
              ))}
            </select>
          </div>
          <div className="form-control w-44">
            <select
              className="select select-bordered w-full"
              value={logStatusFilter}
              onChange={(e) => {
                setLogStatusFilter(e.target.value as TerminalLogStatus | "all");
                setLogCurrentPage(1);
              }}
            >
              <option value="all">All status</option>
              {LOG_STATUS_OPTIONS.map((s) => (
                <option key={s} value={s}>
                  {s.replace(/_/g, " ")}
                </option>
              ))}
            </select>
          </div>
          <span className="text-sm text-base-content/70">
            Showing {filteredLogs.length} of {terminalLogs.length} logs
          </span>
        </div>
      </div>
      {terminalLogsLoading ? (
        <div className="flex justify-center py-16">
          <span className="loading loading-spinner loading-lg text-primary" />
        </div>
      ) : (
        <>
          <TerminalLogTable logs={paginatedLogs} />
          <div className="mt-4 flex items-center justify-between">
            <span className="text-sm text-base-content/70">
              Page {currentLogPage} of {logTotalPages}
            </span>
            <div className="join">
              <button
                type="button"
                className="btn btn-sm join-item"
                onClick={() => setLogCurrentPage((prev) => Math.max(1, prev - 1))}
                disabled={currentLogPage === 1}
              >
                Prev
              </button>
              <button
                type="button"
                className="btn btn-sm join-item"
                onClick={() =>
                  setLogCurrentPage((prev) => Math.min(logTotalPages, prev + 1))
                }
                disabled={currentLogPage === logTotalPages}
              >
                Next
              </button>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
