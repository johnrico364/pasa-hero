"use client";

import axios from "axios";
import { useState } from "react";

export type RouteTypeFilter = "normal" | "vice_versa";

export const useGetRouteByRouteCode = () => {
  const [error, setError] = useState<string | null>(null);

  const getRouteByRouteCode = async (
    routeCode: string,
    routeType?: RouteTypeFilter,
  ) => {
    try {
      const baseUrl = process.env.NEXT_PUBLIC_API_URL ?? "";
      const encoded = encodeURIComponent(routeCode.trim());
      const qs =
        routeType != null ? `?route_type=${encodeURIComponent(routeType)}` : "";
      const { data: response } = await axios.get(
        `${baseUrl}/api/routes/code/${encoded}${qs}`,
      );
      return response;
    } catch (error) {
      if (axios.isAxiosError(error)) {
        setError(error.response?.data?.message);
        return error.response?.data;
      }
      setError("Unexpected error");
    }
  };
  return { getRouteByRouteCode, error };
};
