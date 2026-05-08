"use client";

import axios from "axios";
import { useCallback, useState } from "react";

export const useDeleteBus = () => {
  const [error, setError] = useState<string | null>(null);

  const deleteBus = useCallback(async (busId: string) => {
    try {
      setError(null);
      const baseUrl = process.env.NEXT_PUBLIC_API_URL ?? "";
      const { data: response } = await axios.delete(
        `${baseUrl}/api/buses/${busId}`,
      );
      return response;
    } catch (err) {
      if (axios.isAxiosError(err)) {
        const msg = err.response?.data?.message ?? err.response?.data?.error;
        setError(typeof msg === "string" ? msg : "Request failed");
      } else {
        setError("Unexpected error");
      }
    }
  }, []);
  return { deleteBus, error };
};
