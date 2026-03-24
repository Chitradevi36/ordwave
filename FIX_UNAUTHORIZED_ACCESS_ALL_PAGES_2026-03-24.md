# Fix Unauthorized Access - All Detail Pages

## Problem Summary

When users try to access detail pages (orders, invoices, customers, etc.) for records they don't have permission to view (by changing the URL), the page turns blank instead of showing a friendly error message.

**Root Cause:** API returns 403/404, but the UI just renders `null` without any error message.

## Solution

### 1️⃣ Reusable Error Component (Already Created ✅)

**File:** `web/components/errors/access-denied-error.tsx`

This component handles all error cases with appropriate messages based on HTTP status.

### 2️⃣ Pages to Fix

Apply this fix to all detail pages with dynamic `[id]` parameters:

| Page | Path | Severity |
|------|------|----------|
| Orders | `web/app/orders/[id]/page.tsx` | ✅ FIXED |
| Sales Invoices | `web/app/sales-invoices/[id]/page.tsx` | ⏳ Needs review |
| Customers | `web/app/customers/[id]/page.tsx` | ⏳ Needs review |
| Delivery | `web/app/delivery/[id]/page.tsx` | ⏳ Needs fix |
| Suppliers | `web/app/suppliers/[id]/page.tsx` | ⏳ Needs fix |
| Products | `web/app/products/[id]/page.tsx` | ⏳ Needs fix |
| Users | `web/app/users/[id]/page.tsx` | ⏳ Needs fix |
| Returns | `web/app/returns/[id]/page.tsx` | ⏳ Needs fix |
| Collections | `web/app/collections/[id]/page.tsx` | ⏳ Needs fix |
| Schemes | `web/app/schemes/[id]/page.tsx` | ⏳ Needs fix |
| Routes | `web/app/routes/[id]/page.tsx` | ⏳ Needs fix |
| Beats | `web/app/beats/[id]/page.tsx` | ⏳ Needs fix |
| Purchase Invoices | `web/app/purchases/invoices/[id]/page.tsx` | ⏳ Needs fix |
| Credit Notes | `web/app/credit-notes/[id]/page.tsx` | ⏳ Needs fix |
| Pick Lists | `web/app/operations/pick-lists/[id]/page.tsx` | ⏳ Needs fix |
| Inventory Stock | `web/app/inventory/stock/[id]/page.tsx` | ⏳ Needs fix |
| Inventory Transfers | `web/app/inventory/transfers/[id]/page.tsx` | ⏳ Needs fix |
| Branches Settings | `web/app/settings/branches/[id]/page.tsx` | ⏳ Needs fix |
| Price Lists | `web/app/products/price-lists/[id]/page.tsx` | ⏳ Needs fix |
| Supplier Debit Notes | `web/app/supplier-debit-notes/[id]/page.tsx` | ⏳ Needs fix |
| Accounting Integrations | `web/app/accounting/integrations/[id]/page.tsx` | ⏳ Needs fix |

## How to Apply the Fix

### Pattern for Any Detail Page

**Step 1: Add error state**
```typescript
const [error, setError] = useState<{ status: number; message: string } | null>(null);
const [loading, setLoading] = useState(true);
```

**Step 2: Set error on failed fetch**
```typescript
if (!response.ok) {
  setError({
    status: response.status,
    message: responseJson.errors?.[0] ?? `Failed to load ${resourceType}`
  });
  return;
}
```

**Step 3: Add error JSX in render**
```typescript
if (loading) {
  // Show loading...
}

if (error) {
  return <AccessDeniedError
    status={error.status}
    message={error.message}
    backLink="/your-list-page"
    resourceType="Order" // or "Invoice", "Customer", etc.
  />;
}

if (!resource) return null;

// Rest of your JSX...
```

## Priority Tiers

### 🔴 CRITICAL (Fix First)
These are the most commonly accessed detail pages:
1. Orders (`orders/[id]`) - ✅ FIXED
2. Sales Invoices (`sales-invoices/[id]`)
3. Customers (`customers/[id]`)
4. Delivery (`delivery/[id]`)
5. Suppliers (`suppliers/[id]`)

### 🟡 HIGH (Fix Next)
Common in specific workflows:
1. Products (`products/[id]`)
2. Returns (`returns/[id]`)
3. Purchase Invoices (`purchases/invoices/[id]`)
4. Credit Notes (`credit-notes/[id]`)

### 🟢 MEDIUM (Fix When Time Allows)
Administrative/specialized pages:
1. Users (`users/[id]`)
2. Routes (`routes/[id]`)
3. Schemes (`schemes/[id]`)
4. Collections (`collections/[id]`)
5. All settings/configuration pages

## Quick Fix Template

Copy this template for each page you're fixing:

```typescript
'use client';

import { useState, useEffect, useCallback } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { AccessDeniedError } from '@/components/errors/access-denied-error';

export default function DetailPage() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  
  const [resource, setResource] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<{ status: number; message: string } | null>(null);

  useEffect(() => {
    if (!params.id) return;
    
    const fetch = async () => {
      setLoading(true);
      setError(null);
      try {
        const res = await fetch(`/api/v1/resource/${params.id}`);
        if (!res.ok) {
          setError({
            status: res.status,
            message: (await res.json()).errors?.[0] ?? 'Failed to load resource'
          });
          return;
        }
        setResource(await res.json());
      } catch (err) {
        setError({
          status: 500,
          message: 'An error occurred'
        });
      } finally {
        setLoading(false);
      }
    };

    void fetch();
  }, [params.id]);

  if (loading) {
    return <div>Loading...</div>;
  }

  if (error) {
    return <AccessDeniedError
      status={error.status}
      message={error.message}
      backLink="/resources"
      resourceType="Resource"
    />;
  }

  if (!resource) return null;

  return <div>{/* Your content */}</div>;
}
```

## Checklist for Implementation

### For Each Page:
- [ ] Add error state
- [ ] Update fetch logic to catch and set errors
- [ ] Add error JSX before main content JSX
- [ ] Import AccessDeniedError component
- [ ] Test with invalid ID (should show error page)
- [ ] Test with unauthorized access (403)
- [ ] Test with valid ID (should show content)

## Testing Each Fix

**Test 1: Valid resource**
```
Navigate to: /orders/1
Expected: Loads order details
```

**Test 2: Invalid resource (404)**
```
Navigate to: /orders/99999
Expected: Shows "Order Not Found" error page
```

**Test 3: Unauthorized resource (403)**
```
Navigate to: /orders/{other-orgs-order-id}
Expected: Shows "Access Denied" error page
```

## Files to Modify

Priority order (CRITICAL → HIGH → MEDIUM):

```
CRITICAL:
├─ web/app/sales-invoices/[id]/page.tsx
├─ web/app/customers/[id]/page.tsx
├─ web/app/delivery/[id]/page.tsx
└─ web/app/suppliers/[id]/page.tsx

HIGH:
├─ web/app/products/[id]/page.tsx
├─ web/app/returns/[id]/page.tsx
├─ web/app/purchases/invoices/[id]/page.tsx
└─ web/app/credit-notes/[id]/page.tsx

MEDIUM:
├─ web/app/users/[id]/page.tsx
├─ web/app/routes/[id]/page.tsx
├─ web/app/schemes/[id]/page.tsx
├─ web/app/collections/[id]/page.tsx
├─ web/app/beats/[id]/page.tsx
├─ web/app/operations/pick-lists/[id]/page.tsx
├─ web/app/inventory/stock/[id]/page.tsx
├─ web/app/inventory/transfers/[id]/page.tsx
├─ web/app/settings/branches/[id]/page.tsx
├─ web/app/products/price-lists/[id]/page.tsx
├─ web/app/supplier-debit-notes/[id]/page.tsx
└─ web/app/accounting/integrations/[id]/page.tsx
```

## Implementation Time Estimate

- **CRITICAL tier (4 pages):** 2-3 hours
- **HIGH tier (4 pages):** 2-3 hours
- **MEDIUM tier (8+ pages):** 4-5 hours
- **Total:** 8-11 hours for all pages

## Deployment Note

This fix improves UX and security:
✅ Users see friendly error pages instead of blank screens
✅ Better understanding of why access is denied
✅ Reduced support tickets about blank pages
✅ More professional user experience

Deploy CRITICAL tier first, then HIGH tier, then MEDIUM tier incrementally.
