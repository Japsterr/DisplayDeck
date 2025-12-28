import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  /* config options here */
  output: "standalone",
  async rewrites() {
    return [
      {
        source: "/api/:path*",
        destination: "http://server:2001/:path*",
      },
      {
        source: "/minio/:path*",
        destination: "http://minio:9000/:path*",
      },
    ];
  },
};

export default nextConfig;
