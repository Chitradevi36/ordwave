# 🎯 ACTION PLAN: Fix Authorization Bypass - Top Priority Pages

**Status:** Orders page ✅ FIXED | AccessDeniedError component ✅ READY
**Next:** Apply fix to critical pages (Sales Invoices, Customers, Delivery, Suppliers)

## Priority 1: Sales Invoices Detail Page

**File:** `web/app/sales-invoices/[id]/page.tsx`

### What to do:
1. Add error state at top with other useState
2. Update fetch error handling
3. Add error display after loading check
4. Import AccessDeniedError

### Current Pattern (needs fix):
The page likely has:
- Fetch from `/api/v1/sales_invoices/{id}`
- No error state
- Returns null if fetch fails

### Fix Template (Copy this exactly):

After line with `const [loading, setLoading] = useState(true);`, add:
```typescript
const [error, setError] = useState<{ status: number; message: string } | null>(null);
```

In the fetch error handler, replace:
```typescript
// OLD: Silent failure
if (!res.ok) {
  // Maybe logged but UI doesn't show error
  return;
}
```

With:
```typescript
// NEW: Show error to user
if (!res.ok) {
  const json = await res.json();
  setError({
    status: res.status,
    message: json.errors?.[0] ?? 'Failed to load sales invoice'
  });
  return;
}
```

After `if (loading) { return ... }`, add:
```typescript
if (error) {
  return <AccessDeniedError
    status={error.status}
    message={error.message}
    backLink="/sales-invoices"
    resourceType="Sales Invoice"
  />;
}
```

Make sure to import at top:
```typescript
import { AccessDeniedError } from '@/components/errors/access-denied-error';
```

---

## Priority 2: Customers Detail Page  

**File:** `web/app/customers/[id]/page.tsx`

### What to do:
Same 4 steps as Sales Invoices
- Add error state
- Update fetch error handling
- Add error JSX
- Import component

### Specific Details:
- Component URL: `/api/v1/customers/{id}`
- Error message: "Failed to load customer"
- Back link: `/customers`
- Resource type: "Customer"

---

## Priority 3: Delivery Detail Page

**File:** `web/app/delivery/[id]/page.tsx`

### What to do:
Same 4 steps as above
- Add error state
- Update fetch error handling  
- Add error JSX
- Import component

### Specific Details:
- Component URL: `/api/v1/deliveries/{id}` or similar
- Error message: "Failed to load delivery"
- Back link: `/delivery`
- Resource type: "Delivery"

---

## Priority 4: Suppliers Detail Page

**File:** `web/app/suppliers/[id]/page.tsx`

### What to do:
Same 4 steps as above
- Add error state
- Update fetch error handling
- Add error JSX
- Import component

### Specific Details:
- Component URL: `/api/v1/suppliers/{id}`
- Error message: "Failed to load supplier"
- Back link: `/suppliers`
- Resource type: "Supplier"

---

## How to Implement Quickly

### Method 1: Manual (5-10 mins per page)
For each page:
1. Open the file
2. Find the useState section
3. Add error state
4. Find the fetch error handler
5. Replace the error handling
6. Add error JSX after loading check
7. Add import at top
8. Test

### Method 2: Have Copilot Do It (Recommended)
Ask Copilot: "Fix the authorization bypass in [file path] using the AccessDeniedError component"

---

## Testing Checklist

For **each page** after fixing, test:

```
1. Valid resource (ID of your own data):
   Navigate to page → Should show content ✓

2. Invalid resource (random high ID):
   Navigate to page → Should show "Not Found" error ✓

3. Unauthorized resource (another org's data):
   Navigate to page → Should show "Access Denied" error ✓

4. Error page back button:
   Click back link → Should navigate to list ✓
```

---

## Current Status

| Page | Status | Priority |
|------|--------|----------|
| Orders | ✅ FIXED | — |
| Sales Invoices | ⏳ NEXT | 🔴 CRITICAL |
| Customers | ⏳ NEXT | 🔴 CRITICAL |
| Delivery | ⏳ NEXT | 🔴 CRITICAL |
| Suppliers | ⏳ NEXT | 🔴 CRITICAL |
| Products | ⏳ TODO | 🟡 HIGH |
| Returns | ⏳ TODO | 🟡 HIGH |
| Purchase Invoices | ⏳ TODO | 🟡 HIGH |
| Credit Notes | ⏳ TODO | 🟡 HIGH |

---

## What Changed References

**Fix Pattern Applied to Orders:**
- Added error state: `const [error, setError] = useState(null);`
- Updated fetch: Sets error on 403/404
- Added error JSX: Shows AccessDeniedError component
- Import: `import { AccessDeniedError } from '@/components/errors/access-denied-error';`

**Apply same pattern to Sales Invoices, Customers, Delivery, Suppliers**

---

## Questions?

If any page has a different fetch pattern:
- Check the import statements
- See what API endpoint it uses
- Follow the same error state → fetch handler → error JSX pattern
- Error message can be customized per resource type

Example if fetch uses axios instead:
```typescript
// OLD: axios error handling
.catch(err => {
  console.log(err);  // Silent
});

// NEW: With error state
.catch(err => {
  setError({
    status: err.response?.status ?? 500,
    message: err.response?.data?.errors?.[0] ?? 'Failed to load'
  });
});
```

Same principle, just different library.
