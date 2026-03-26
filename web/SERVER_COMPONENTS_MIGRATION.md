# Server Components Migration Guide

## Status: Documented—awaiting auth strategy migration

### Pre-requisite: Cookie-based authentication

To leverage Next.js Server Components for data fetching, the JWT auth
strategy must move from `localStorage` to **HTTP-only secure cookies**.
Until that change is made, all pages that read `token` from
`useOrgBranch()` must remain Client Components.

**Migration path:**
1. Add `Set-Cookie` header on login response (backend)
2. Create a `getServerSession()` helper that reads the cookie in RSC
3. Move data fetching to RSC `async` pages using `apiClient` with cookies
4. Keep interactive panels (charts, modals, forms) as Client Components with
   `"use client"` at the component boundary—not the page level

### Pattern: Split page into Server Component + Client islands

```tsx
// app/products/page.tsx  (SERVER Component — no "use client")
import { cookies } from "next/headers";
import { apiServer } from "@/lib/api/server";    // server-only apiClient
import { ProductsTable } from "./products-table"; // client island

export default async function ProductsPage({
  searchParams,
}: {
  searchParams: { page?: string; q?: string };
}) {
  const page   = Number(searchParams.page ?? 1);
  const search = searchParams.q ?? "";

  const { data, meta } = await apiServer.get("/api/v1/products", {
    params: { page, per_page: 20, q: search },
  });

  return (
    <AppShell title="Products">
      <ProductsTable
        initialData={data}
        initialMeta={meta}
        search={search}
        page={page}
      />
    </AppShell>
  );
}
```

```tsx
// app/products/products-table.tsx  (CLIENT island)
"use client";

import { useListPage } from "@/lib/hooks/useListPage";
// interactive table with filters, pagination, etc.
```

### Candidate pages for first conversion (after auth migration):
1. `/products` — simple list, no real-time data
2. `/customers` — simple list
3. `/suppliers` — simple list
4. `/invoices` — list with filters

The `/dashboard` page is the **last** candidate because it is highly
interactive, role-dependent, and uses multiple data hooks simultaneously.

### Effort estimate
- Auth strategy change: **2-3 days**
- Per-page conversion: **2-4 hours** each
- Dashboard: **1-2 days** (many client islands)
