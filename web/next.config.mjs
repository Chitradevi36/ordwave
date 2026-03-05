/** @type {import('next').NextConfig} */
const nextConfig = {
  async rewrites() {
    // Strip any trailing /api or /api/v1 from the env var so the destination
    // never doubles the prefix when "/api/:path*" is appended below.
    const backendOrigin = (process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3000')
      .replace(/\/api(\/v\d+)?\/?$/, '');

    return [
      {
        source: '/api/:path*',
        destination: `${backendOrigin}/api/:path*`,
      },
    ];
  },
};

export default nextConfig;
