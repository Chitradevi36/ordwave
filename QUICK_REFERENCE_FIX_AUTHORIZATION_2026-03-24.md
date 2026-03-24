# ⚡ Quick Reference: Fix Authorization Bypass in Any Detail Page

**Time per page:** 5-10 minutes | **Skill level:** Beginner | **Copy-paste ready:** Yes

---

## 🎯 The Fix (4 Simple Steps)

### Step 1: Add Import
**Location:** Top of file with other imports

```typescript
import { AccessDeniedError } from "@/components/errors/access-denied-error";
```

### Step 2: Add Error State
**Location:** With other `useState` declarations

```typescript
const [error, setError] = useState<{ status: number; message: string } | null>(null);
```

### Step 3: Update Fetch Error Handling
**Location:** In the fetch function, update the error handler

Replace this:
```typescript
if (!res.ok) {
  // Maybe silently fails or generic error
}
```

With this:
```typescript
if (!res.ok) {
  const json = await res.json();
  setError({
    status: res.status,
    message: json.errors?.[0] ?? "Failed to load resource"
  });
  return; // Important: exit early!
}
```

### Step 4: Add Error JSX
**Location:** In the render function, BEFORE the `if (!resource)` check

```typescript
if (loading) {
  return <AppShell>Loading...</AppShell>;
}

// ADD THIS NEW CHECK:
if (error) {
  return <AccessDeniedError
    status={error.status}
    message={error.message}
    backLink="/module-list-page"
    resourceType="Resource Name"
  />;
}

// Keep existing check:
if (!resource) return <AppShell>Not found</AppShell>;
```

---

## 📋 Quick Checklist

For each page you fix:

- [ ] Add `import { AccessDeniedError }` line
- [ ] Add error state with `useState`
- [ ] Update fetch error handler to set error state
- [ ] Add `if (error) { return <AccessDeniedError ... />; }` check
- [ ] Set correct `resourceType` name (singular: "Order", "Customer", "Product", etc.)
- [ ] Set correct `backLink` to list page (e.g., "/orders", "/customers")
- [ ] Test with invalid ID → should show 404 not found
- [ ] Test with another org's ID → should show 403 access denied

---

## 🔍 Before & After Examples

### Example 1: Orders Page

**Before:**
```typescript
if (!order) return <AppShell>Order not found</AppShell>;
```

**After:**
```typescript
if (error) {
  return <AccessDeniedError
    status={error.status}
    message={error.message}
    backLink="/orders"
    resourceType="Order"
  />;
}

if (!order) return <AppShell>Order not found</AppShell>;
```

### Example 2: Customer Page

**Before:**
```typescript
if (!customer) {
  return <AppShell><p className="text-text-secondary">Customer not found</p></AppShell>;
}
```

**After:**
```typescript
if (error) {
  return <AccessDeniedError
    status={error.status}
    message={error.message}
    backLink="/customers"
    resourceType="Customer"
  />;
}

if (!customer) {
  return <AppShell><p className="text-text-secondary">Customer not found</p></AppShell>;
}
```

---

## 🎯 Module Resource Types & Links

Use these values for `resourceType` and `backLink`:

| Page | resourceType | backLink |
|------|-------------|----------|
| Orders | "Order" | "/orders" |
| Customers | "Customer" | "/customers" |
| Products | "Product" | "/products" |
| Suppliers | "Supplier" | "/suppliers" |
| Sales Invoices | "Sales Invoice" | "/sales-invoices" |
| Purchase Invoices | "Purchase Invoice" | "/purchases/invoices" |
| Delivery Trips | "Delivery Trip" | "/delivery" |
| Returns | "Return" | "/returns" |
| Credit Notes | "Credit Note" | "/credit-notes" |
| Users | "User" | "/users" |
| Routes | "Route" | "/routes" |
| Schemes | "Scheme" | "/schemes" |
| Collections | "Collection" | "/collections" |
| Beats | "Beat" | "/beats" |
| Pick Lists | "Pick List" | "/operations/pick-lists" |
| Inventory Stock | "Inventory Stock" | "/inventory/stock" |
| Inventory Transfers | "Inventory Transfer" | "/inventory/transfers" |
| Price Lists | "Price List" | "/products/price-lists" |
| Branch Settings | "Branch" | "/settings/branches" |

---

## 🧪 How to Test Your Fix

### Test 1: Valid Resource
1. Navigate to: `/module/123` (real ID)
2. ✅ Should show resource details

### Test 2: Invalid Resource (404)
1. Navigate to: `/module/99999999` (ID that doesn't exist)
2. ✅ Should show "Not Found" error page with back button

### Test 3: Another Org's Resource (403)
1. Navigate to: `/module/{another-orgs-id}`
2. ✅ Should show "Access Denied" error page with back button

### Test 4: Navigation Works
1. Click "Back" or home button on error page
2. ✅ Should navigate away from error page

---

## 🚀 Rapid Execution Tips

### For Copy-Paste Implementation:
1. Find the file in your editor
2. Add import line at top ⏱ 5 seconds
3. Find useState section, add error line ⏱ 10 seconds
4. Find fetch function, add error handling ⏱ 1 minute
5. Find render section, add error JSX ⏱ 1 minute
6. Test the page ⏱ 2 minutes
7. Move to next page

**Total: ~5 minutes per page** (faster than you think!)

### Pro Tips:
- Use Ctrl+F to find patterns like `if (!resource)` or `useEffect`
- Copy the error handling block from previously fixed page
- Test all pages in a batch at the end
- Focus on CRITICAL tier first, then HIGH, then MEDIUM

---

## 🔧 Fetch Pattern Variations

### Pattern A: Simple Fetch + JSON

```typescript
const res = await fetch(url, { headers: authHeaders });
if (!res.ok) {
  const json = await res.json();
  setError({
    status: res.status,
    message: json.errors?.[0] ?? "Failed"
  });
  return;
}
const json = await res.json();
setResource(json.data);
```

### Pattern B: Chained Promise

```typescript
fetch(url, { headers: authHeaders })
  .then((r) => {
    if (!r.ok) {
      return r.json().then((j) => {
        setError({
          status: r.status,
          message: j.errors?.[0] ?? "Failed"
        });
      });
    }
    return r.json().then((j) => setResource(j.data));
  })
  .catch((e) => setError({ status: 500, message: e.message }));
```

### Pattern C: Axios (if used)

```typescript
axios.get(url, { headers: authHeaders })
  .then((r) => setResource(r.data.data))
  .catch((e) => setError({
    status: e.response?.status ?? 500,
    message: e.response?.data?.errors?.[0] ?? "Failed"
  }));
```

---

## ❌ Common Mistakes

### ❌ Mistake 1: Forgetting the `return` statement

```typescript
// WRONG - continues to process even though error is set
if (!res.ok) {
  setError({ status: res.status, message: "..." });
  // No return! - Still tries to parse json.data below
}
const json = await res.json();
setResource(json.data); // Fails if res wasn't ok!
```

```typescript
// CORRECT - exits early
if (!res.ok) {
  setError({ status: res.status, message: "..." });
  return; // ✅ Exit immediately
}
```

### ❌ Mistake 2: Wrong error check order

```typescript
// WRONG - checks error AFTER checking resource
if (!resource) return <p>Not found</p>;
if (error) return <AccessDeniedError ... />; // Never reached!
```

```typescript
// CORRECT - checks error FIRST
if (error) return <AccessDeniedError ... />; // ✅ Check error first
if (!resource) return <p>Not found</p>;
```

### ❌ Mistake 3: Missing error state in cleanup

```typescript
// WRONG - error state not initialized
// Missing: const [error, setError] = useState(null);

// CORRECT
const [error, setError] = useState<{ status: number; message: string } | null>(null);
```

---

## 📞 Troubleshooting

**Q: I added the import but TypeScript shows error**
A: Make sure component file exists at `web/components/errors/access-denied-error.tsx`

**Q: Error page shows but looks wrong**
A: Check that `backLink` has leading slash: `/orders` not `orders`

**Q: Error not showing up**
A: Make sure error check is BEFORE resource check in render

**Q: Still seeing blank page**
A: Verify `return` statement after `setError()` in fetch function

---

## ✅ Pages Already Fixed

These can be used as reference implementations:

1. ✅ `web/app/orders/[id]/page.tsx`
2. ✅ `web/app/sales-invoices/[id]/page.tsx`
3. ✅ `web/app/customers/[id]/page.tsx`
4. ✅ `web/app/delivery/[id]/page.tsx`
5. ✅ `web/app/suppliers/[id]/page.tsx`
6. ✅ `web/app/products/[id]/page.tsx`

Copy the pattern from any of these!

---

## 🎯 Priority Order

**Fix in this order:**
1. Returns
2. Purchase Invoices
3. Credit Notes
4. Users
5. Routes
6. Schemes
7. Collections
8. Beats
9. Pick Lists
10. Inventory Stock
11. ... (then remaining MEDIUM tier)

---

## ⏱ Timing Estimates

- **Simple page** (2-3 useState): 5 minutes
- **Medium page** (4-6 useState): 8 minutes
- **Complex page** (10+ useState): 10 minutes

**Batch timings:**
- 3 pages: 20 minutes
- 5 pages: 30 minutes
- 10 pages: 1 hour
- 20 pages: 2 hours

---

## 🚀 Ready to Go!

You have everything needed to fix any detail page in 5-10 minutes.

**Reference files:**
- `ACTION_PLAN_CRITICAL_FIXES_2026-03-24.md` - Detailed walkthrough
- `FIX_UNAUTHORIZED_ACCESS_ALL_PAGES_2026-03-24.md` - Full guide
- `AUTHORIZATION_FIX_PROGRESS_2026-03-24.md` - Progress tracking

**What you need:**
- This quick reference card ✅
- Access to detail page file ✅
- Code editor ✅
- ~5 minutes per page ✅

Start with the next page on the priority list!
