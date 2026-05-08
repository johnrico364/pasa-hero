import type { NextConfig } from "next";

const apiUrl = process.env.NEXT_PUBLIC_API_URL;
let apiOrigin: URL | null = null;
if (apiUrl) {
  try {
    apiOrigin = new URL(apiUrl);
  } catch {
    apiOrigin = null;
  }
}

const nextConfig: NextConfig = {
  images: {
    remotePatterns: apiOrigin
      ? [
          {
            protocol: apiOrigin.protocol.replace(":", "") as "http" | "https",
            hostname: apiOrigin.hostname,
            port: apiOrigin.port || undefined,
            pathname: "/images/**",
          },
        ]
      : [],
  },
};

export default nextConfig;
