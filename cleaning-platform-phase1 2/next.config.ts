import type { NextConfig } from "next";
import createNextIntlPlugin from "next-intl/plugin";

const withNextIntl = createNextIntlPlugin("./i18n/request.ts");

const nextConfig: NextConfig = {
  reactStrictMode: true,
  images: {
    // Supabase Storage public bucket host(s) will be added here once the
    // project URL is known (Phase 2+). Left empty on purpose — no
    // placeholder/fake hostnames.
    remotePatterns: [],
  },
};

export default withNextIntl(nextConfig);
