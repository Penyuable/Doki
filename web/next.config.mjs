import { fileURLToPath } from 'node:url';

/** @type {import('next').NextConfig} */
const nextConfig = {
  // Static export: seluruh app berjalan di browser (mode offline memakai
  // localStorage), jadi hasil build `out/` bisa di-host di CDN statis mana pun.
  output: 'export',
  reactStrictMode: true,
  trailingSlash: true,
  images: { unoptimized: true },
  poweredByHeader: false,
  // Kunci root ke folder web/ (ada lockfile lain di folder induk).
  outputFileTracingRoot: fileURLToPath(new URL('.', import.meta.url)),
};

export default nextConfig;
