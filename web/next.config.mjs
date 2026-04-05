/** @type {import('next').NextConfig} */
const isDev = process.env.NODE_ENV !== 'production';

const nextConfig = {
  distDir: 'build',
  eslint: {
    ignoreDuringBuilds: true,
  },

  experimental: {
    ...(isDev ? { cpus: 1, workerThreads: false } : {}),
  },

  // ── Security headers ──────────────────────────────────────────────────────
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: [
          { key: 'X-Frame-Options',        value: 'DENY' },
          { key: 'X-Content-Type-Options',  value: 'nosniff' },
          { key: 'Referrer-Policy',         value: 'strict-origin-when-cross-origin' },
          { key: 'Permissions-Policy',      value: 'camera=(), microphone=(), geolocation=(self)' },
          ...(isDev ? [] : [
            { key: 'Strict-Transport-Security', value: 'max-age=63072000; includeSubDomains; preload' },
            {
              key: 'Content-Security-Policy',
              value: [
                "default-src 'self'",
                "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://www.googletagmanager.com https://www.google-analytics.com",
                "style-src 'self' 'unsafe-inline'",
                "img-src 'self' data: blob: https:",
                "font-src 'self' data:",
                "connect-src 'self' https://www.google-analytics.com https://analytics.google.com " +
                  (process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3000'),
                "frame-ancestors 'none'",
                "base-uri 'self'",
                "form-action 'self'",
              ].join('; '),
            },
          ]),
        ],
      },
    ];
  },

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
