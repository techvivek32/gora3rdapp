import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  // Let the reverse proxy (nginx) do gzip. Next.js compressing too caused
  // double-encoded responses that rendered as binary garbage in the browser.
  compress: false,
  // SECURITY: no `serverActions.allowedOrigins: ['*']` and no wildcard CORS —
  // both disabled cross-site protection. The admin frontend calls its own /api
  // same-origin, so Next.js defaults (same-origin only) are correct and safe.
  images: {
    remotePatterns: [
      { protocol: 'https', hostname: 'media.goracabs.com' },
      { protocol: 'https', hostname: '*.r2.cloudflarestorage.com' },
      { protocol: 'https', hostname: 'lh3.googleusercontent.com' },
    ],
  },
};

export default nextConfig;
