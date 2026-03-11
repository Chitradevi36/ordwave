# OrdWave — Phase 0: Repo Cleanup & Architecture Foundation

## Goal
Clean up naming, fix inconsistencies, set up Flutter project properly, add web infrastructure guardrails.

**Duration:** ~1 week

## Modules Touched
- All (naming standardization)
- Web app shell
- Flutter project initialization

---

## Backend Tasks

### B0.1 — Standardize Product Naming
- Replace all instances of "OmniDist OMS" with "OrdWave" in:
  - `backend/db/seeds.rb` (org name, email domains)
  - `backend/app/views/` (mailer templates)
  - `web/app/layout.tsx` (metadata title)
  - `docs/ARCHITECTURE_OVERVIEW.md`
- Change seed email domains from `@riceoms.dev` to `@orderlanepro.dev`
- Update `web/components/layout/sidebar.tsx` brand text to "OrdWave"

### B0.2 — Deprecate `return_records`
- Create migration to add `return_request_id` FK on `return_records` (for linking legacy data)
- Create data migration that generates `return_request` + `return_line` records for existing `return_records`
- Add deprecation notice to `ReturnRecord` model (`ActiveSupport::Deprecation.warn`)
- DO NOT drop table yet — do that in Phase 5 after verifying all references migrated

### B0.3 — Fix Role Name Consistency
- Audit all seed files, prompt docs, and test factories for role name references
- Ensure only these 7 names used everywhere: `owner`, `admin`, `manager`, `sales_rep`, `warehouse_staff`, `accountant`, `driver`
- Fix any frontend code referencing `accounts` or `warehouse` (this may already be correct in nav.config.ts)

### B0.4 — Add idempotency_key to Payment
- Migration: `add_column :payments, :idempotency_key, :string`
- Add unique index: `add_index :payments, :idempotency_key, unique: true, where: "idempotency_key IS NOT NULL"`
- Update `PaymentsController#create` to check for existing payment with same idempotency_key

---

## Web Tasks

### W0.1 — Add `middleware.ts`
```typescript
// web/middleware.ts
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;
  
  // Public routes that don't require auth
  const publicRoutes = ['/login', '/signup', '/forgot-password', '/reset-password', '/invite/accept'];
  if (publicRoutes.some(route => pathname.startsWith(route))) {
    return NextResponse.next();
  }
  
  // Check for auth token in cookie (set by client on login)
  const token = request.cookies.get('auth_token')?.value;
  if (!token) {
    return NextResponse.redirect(new URL('/login', request.url));
  }
  
  return NextResponse.next();
}

export const config = {
  matcher: ['/((?!api|_next/static|_next/image|favicon.ico|robots.txt).*)'],
};
```
Note: This requires storing auth token in an httpOnly cookie in addition to localStorage, or using a simpler approach with a cookie flag set on login.

### W0.2 — Add Error/Loading Boundaries
- Create `web/app/error.tsx` — global error boundary with retry button
- Create `web/app/loading.tsx` — global loading skeleton
- Create `web/app/not-found.tsx` — 404 page with navigation back
- Create route-segment boundaries for key sections: `web/app/(dashboard)/error.tsx`, etc.

### W0.3 — Activate Workspace Tabs
- Uncomment all workspace tabs in `web/components/workspace/workspace.config.ts`
- Verify each workspace hub page renders tabs correctly
- Add proper `rolesAllowed` to each tab

### W0.4 — Standardize API Fetching
- Create shared React Query hooks in `web/lib/api/hooks/`:
  - `useCustomers.ts`
  - `useProducts.ts`
  - `useDeliveryTrips.ts`
  - `usePayments.ts`
  - `useInvoices.ts`
  - `useReturns.ts`
  - `useCreditNotes.ts`
  - `useSuppliers.ts`
  - `useInventory.ts`
  - `useNotifications.ts` (prep for Phase 1)
- Each hook: uses Axios client, returns `{ data, isLoading, error, refetch }`, handles pagination

---

## Mobile (Flutter) Tasks

### M0.1 — Initialize Flutter Project Properly
- Create `mobile_flutter/pubspec.yaml` with all dependencies from resolved `package_config.json`
- Run `flutter create --platforms android,ios .` to generate platform dirs
- Verify project compiles and runs on Android emulator

### M0.2 — Create Base Project Structure
Create the full `lib/` directory tree:
```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── theme/
│   │   ├── app_theme.dart
│   │   ├── colors.dart
│   │   └── typography.dart
│   ├── network/
│   │   ├── api_client.dart
│   │   ├── auth_interceptor.dart
│   │   └── connectivity_service.dart
│   ├── storage/
│   │   ├── secure_storage.dart
│   │   └── preferences.dart
│   └── utils/
│       ├── currency.dart
│       └── validators.dart
├── features/ (empty feature folders)
└── shared/
    └── widgets/ (empty)
```

### M0.3 — Set Up Theme
- Create `colors.dart` with all `OlColors` constants matching web design tokens
- Create `typography.dart` with text styles
- Create `app_theme.dart` with `ThemeData` using these tokens
- Use Inter font (add to assets/fonts/)

### M0.4 — Set Up Dio + Auth Interceptor
- Create `api_client.dart` with Dio instance, base URL from env/config
- Create `auth_interceptor.dart` that injects `Authorization: Bearer <token>` + `X-Organization-Id` headers
- Handle 401 → clear tokens → redirect to login
- Handle 402 → show upgrade prompt

### M0.5 — Set Up GoRouter Skeleton
- Create `app.dart` with `MaterialApp.router` + GoRouter
- Define initial routes: `/splash`, `/login`, `/home`
- Add auth redirect guard (if no token → `/login`)
- Add role-based home redirect

---

## Migrations Needed
1. `add_idempotency_key_to_payments` — add `idempotency_key` string column with unique index
2. `add_return_request_id_to_return_records` — add FK for deprecation linkage

## API Changes
- None (cleanup only)

## Acceptance Criteria
- [ ] Web loads with server-side auth guard — unauthenticated users redirected to `/login`
- [ ] Error/loading/404 boundary files render correctly
- [ ] All workspace tabs visible and clickable
- [ ] Flutter project compiles and runs — shows a blank themed screen
- [ ] Flutter Dio client can successfully call `GET /health` endpoint
- [ ] All seed data uses "OrdWave" branding
- [ ] All tests pass after naming fixes
- [ ] `return_records` have deprecation warning in model

## Demo Scenarios Enabled
- Clean branded experience (no "OmniDist" / "RiceOMS" confusion)
- Professional error handling (error/loading/404 pages)
- Flutter app boots and shows themed splash screen
