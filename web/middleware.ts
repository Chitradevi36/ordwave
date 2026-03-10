import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

// Routes accessible without authentication
const PUBLIC_ROUTES = [
  '/login',
  '/signup',
  '/forgot-password',
  '/reset-password',
  '/invite/accept',
  '/activation',
];

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  // Allow public routes through
  if (PUBLIC_ROUTES.some((route) => pathname.startsWith(route))) {
    return NextResponse.next();
  }

  // Check for the auth presence cookie set on login
  // (The actual JWT stays in localStorage; this cookie is a lightweight auth signal
  //  that is readable by middleware without exposing the token to the server)
  const authPresent = request.cookies.get('auth_present')?.value;

  if (!authPresent) {
    const loginUrl = new URL('/login', request.url);
    loginUrl.searchParams.set('next', pathname);
    return NextResponse.redirect(loginUrl);
  }

  return NextResponse.next();
}

export const config = {
  matcher: [
    /*
     * Match all request paths EXCEPT:
     * - api routes
     * - _next/static (static files)
     * - _next/image (image optimisation)
     * - favicon, robots, public assets
     */
    '/((?!api|_next/static|_next/image|favicon.ico|robots.txt|fonts).*)',
  ],
};
