"use client";

import axios from "axios";
import { useCallback, useState } from "react";

export const usePostBusStop = () => {
  const [error, setError] = useState<string | null>(null);

  const postBusStop = useCallback(async (busStop: unknown) => {
    setError(null);
    try {
      const baseUrl = process.env.NEXT_PUBLIC_API_URL ?? "";
      const { data: response } = await axios.post(
        `${baseUrl}/api/route-stops`,
        busStop,
      );
      return response;
    } catch (error) {
      if (axios.isAxiosError(error)) {
        const data = error.response?.data;
        setError(
          typeof data?.message === "string" ? data.message : "Request failed",
        );
        return data;
      }
      setError("Unexpected error");
      return { success: false, message: "Unexpected error" };
    }
  }, []);
  return { postBusStop, error };
};
