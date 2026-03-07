# Plan: Role-based Dashboard + Seed All Users

## Overview

Role views as separate components in `web/components/dashboard/`, plus a dedicated `admin2@riceoms.dev` for testing admin-vs-owner behaviour.

---

## Step 1 — Fix role name mismatch in `web/components/layout/nav.config.ts`

- `UserRole` type: replace `"accounts"` → `"accountant"`, `"warehouse"` → `"warehouse_staff"` (keep `string` catch-all)
- Update every `rolesAllowed` array in `WORKSPACE_NAV` and `CREATE_ACTIONS` (Finance, Insights, Inventory, and several create actions) to use the corrected names
- **Prerequisite** — without this, accountant/warehouse users get a broken sidebar today

---

## Step 2 — Seed 5 new users in `backend/db/seeds.rb`

Insert after `puts '  == Vehicles and drivers seeded.'` (~line 346).

| Email | Name | Role |
|---|---|---|
| `admin2@riceoms.dev` | Rakesh Verma | `admin` |
| `manager@riceoms.dev` | Priya Sharma | `manager` |
| `salesrep@riceoms.dev` | Arjun Reddy | `sales_rep` |
| `accountant@riceoms.dev` | Kavitha Nair | `accountant` |
| `warehouse@riceoms.dev` | Ganesh Pillai | `warehouse_staff` |

Pattern matches driver seeding: `find_or_initialize_by(email:)`, password only set `if new_record? || encrypted_password.blank?`, `Membership.exists?` guard.

Update the footer `puts` block to list all 9 dev accounts.

---

## Step 3 — Create 4 role-specific view components in `web/components/dashboard/`

All components accept `{ data: DashboardData | undefined; isLoading: boolean; isError: boolean }` props and use the existing `KpiCard`, `Badge`, `Card` from shared UI.

### `SalesRepView.tsx`
- KPI row: Orders Today, Collections MTD, Outstanding
- Sparkline of last 14 days orders_value
- Recent orders table (reusable inner component lifted from `page.tsx`)
- Action buttons: New Order, View Customers, View Beats

### `AccountantView.tsx`
- KPI row: Collections MTD, Outstanding, Overdue, Collection Rate %
- Credit risk section: risky accounts, blocked accounts, total overdue (from `data.credit`)
- Quick-link row: Finance, Collections, Sales Invoices, Credit Notes, Advance Payments

### `WarehouseView.tsx`
- KPI row: Low Stock, Zero Stock, Dead Stock (from `data.inventory`)
- Alert ribbon — inventory-type alerts only
- Action buttons: Stock Transfer, Receive Purchase, Stock Adjustment, View Inventory

### `DriverView.tsx`
- Minimal card: note that trips are managed from the mobile app
- Shows Orders Today + Pending count from `data.orders`
- Big CTA links to `/delivery` and `/operations`

---

## Step 4 — Update `web/app/dashboard/page.tsx`

- Import `useCurrentRole` from `@/lib/hooks/use-current-role`
- Import the four new view components
- After `const { data, isLoading, isError } = useDashboardData()` add `const role = useCurrentRole()`
- Replace the main JSX body with a `switch(role)` inside `<AppShell>`:
  - `"sales_rep"` → `<SalesRepView …>`
  - `"accountant"` → `<AccountantView …>`
  - `"warehouse_staff"` → `<WarehouseView …>`
  - `"driver"` → `<DriverView …>`
  - All others (`"owner"` / `"admin"` / `"manager"` / `undefined`) → existing full dashboard body (unchanged, just wrapped)
- Greeting header stays visible for all roles (role-neutral)

---

## Verification

- `rails db:seed` — confirm 9 accounts listed in output, no errors
- Login as each of the 5 new users and verify:
  - `admin2@riceoms.dev` → full owner-style dashboard, all nav items visible
  - `manager@riceoms.dev` → full dashboard; Finance and Inventory visible in nav
  - `salesrep@riceoms.dev` → `SalesRepView`; Finance/Insights nav items hidden
  - `accountant@riceoms.dev` → `AccountantView`; Sales/Customers/Operations nav items hidden
  - `warehouse@riceoms.dev` → `WarehouseView`; Finance/Insights nav items hidden
- TypeScript: `pnpm tsc --noEmit` passes in `/web`
- No regression for `admin@riceoms.dev` — still full owner dashboard

---

## Decisions & Constraints

- `manager` keeps the **same full owner view** (branch-scope is handled automatically by `X-Branch-Id` header on API calls)
- Both `admin` and `admin2@riceoms.dev` see the full owner view — the policy difference (`owner_or_admin?` vs `manager_above?`) is enforced at the API level, not the dashboard UX layer
- `DashboardData` is sufficient for all role views — **no new API endpoints needed**
- `use-current-role.ts` is used as-is (no changes); it already reads the `orderlane_profile_cache` localStorage key correctly

---

## All Dev Credentials (post-seed)

| Email | Password | Role |
|---|---|---|
| `admin@riceoms.dev` | `Password@123` | owner |
| `admin2@riceoms.dev` | `Password@123` | admin |
| `manager@riceoms.dev` | `Password@123` | manager |
| `salesrep@riceoms.dev` | `Password@123` | sales_rep |
| `accountant@riceoms.dev` | `Password@123` | accountant |
| `warehouse@riceoms.dev` | `Password@123` | warehouse_staff |
| `driver1@riceoms.dev` | `Password@123` | driver |
| `driver2@riceoms.dev` | `Password@123` | driver |
| `driver3@riceoms.dev` | `Password@123` | driver |
