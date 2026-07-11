import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  async redirects() {
    return [
      {
        source: "/events/:eventSlug/standings/graph",
        destination: "/events/:eventSlug/points-race",
        permanent: true,
      },
    ];
  },
};

export default nextConfig;
