import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  reactStrictMode: true,
  // Cab photos, banners and profile images are served from the API host and
  // whatever CDN the admin pasted in, so remote images are left unoptimised
  // rather than maintained as an allow-list that silently breaks new hosts.
  images: { unoptimized: true },
  eslint: { ignoreDuringBuilds: true },
};

export default nextConfig;
