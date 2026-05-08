"use client";

import axios from "axios";
import { useCallback, useState } from "react";

export const useDeleteDriver = () => {
  const [error, setError] = useState<string | null>(null);

  const deleteDriver = useCallback(async (driverId: string) => {
    try {
      const baseUrl = process.env.NEXT_PUBLIC_API_URL ?? "";
      const { data: response } = await axios.delete(
        `${baseUrl}/api/drivers/${driverId}`,
      );
      return response;
    } catch (error) {
      if (axios.isAxiosError(error)) {
        setError(error.response?.data.message);
      }
      return null;
    }
  }, []);
  return { deleteDriver, error };
};
