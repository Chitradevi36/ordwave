# OrdWave — Phase 2: Retailer + Product + Pricing Foundation

## Goal
CRM and catalog fully functional on web with enhanced UX. Mobile can search retailers and view profiles with cached data.

**Duration:** ~1.5 weeks

## Modules Touched
- Customers/Retailers (web enhancement + mobile build)
- Products (web enhancement + mobile build)
- Price Lists (web enhancement)
- HSN/SAC (web reorganization)
- Credit Accounts (web enhancement)
- Drift local DB (mobile setup)

---

## Backend Tasks

### B2.1 — Enhanced Customer Endpoint for Mobile
Add `?include=credit_account,recent_orders,recent_payments` query param to `GET /api/v1/customers/:id`:
```ruby
# In CustomersController#show
if params[:include].present?
  includes = params[:include].split(',')
  response = customer_data
  response[:credit_account] = customer.credit_account if includes.include?('credit_account')
  response[:recent_orders] = customer.sales_orders.order(created_at: :desc).limit(5) if includes.include?('recent_orders')
  response[:recent_payments] = customer.payments.order(created_at: :desc).limit(5) if includes.include?('recent_payments')
end
```

### B2.2 — Customer Activity Timeline Endpoint
```ruby
# GET /api/v1/customers/:id/timeline
# Returns chronological list of events:
# - Orders (created, approved, delivered)
# - Payments (confirmed)
# - Credit changes (limit change, block/unblock)
# - Visits (check-in, check-out)
# Paginated, filterable by event_type
```
Implementation: Query `audit_logs` where `auditable_type IN ('SalesOrder','Payment','CreditAccount','VisitLog')` and related customer_id.

### B2.3 — Product with Stock Endpoint for Mobile
Add stock availability to product list response:
```ruby
# GET /api/v1/products?include=stock
# Each product includes: { ..., stock_available: 150, stock_reserved: 20 }
# Scoped to current branch's inventory_level
```

### B2.4 — Effective Price for Customer
Enhance `/api/v1/order_pricing/preview`:
- Accept `customer_id` + `product_ids[]`
- Return effective price per product for that customer (considering standard, tier, retailer-specific, promo price lists)
- Include applicable scheme info

---

## Web Tasks

### W2.1 — Enhance Customer Detail Page
Add/improve these sections on `customers/[id]/page.tsx`:

**Header enhancement:**
- Add risk flag badges: `collection_first` (amber), `watchlist` (amber), `hold_required` (red), `blocked` (red)
- Add "Last visited: 3 days ago" and "Next visit: Tomorrow" meta
- Add quick action button: "Create Order" → navigates to `/orders/new?customer_id=...`

**Outstanding summary banner (NEW component: `SummaryBanner`):**
- Display: Total Outstanding ₹45,000 | Overdue ₹12,000 (15 days) | Last Payment ₹8,000 (Mar 5) | Last Order ₹15,000 (Mar 7)

**Credit tab enhancement:**
- Add utilization gauge chart (circular progress: used/limit)
- Add overdue ageing breakdown bar chart (current/1-14d/15-29d/30-59d/60d+)
- Add credit limit change history timeline

**New tab: Payment History**
- List of confirmed payments with: date, amount, mode, reference, allocated invoices
- Summary: Total paid this month, average collection cycle

**New tab: Activity Timeline**
- Use new `StatusTimeline` component
- Show: orders, payments, visits, credit changes in chronological order
- Filter by event type

### W2.2 — Enhance Customer List Page
- Add "Outstanding" column to table (sortable)
- Add "Overdue" column with red badge for overdue > 0
- Add credit utilization mini-bar in list rows
- Add "Credit Status" filter dropdown (OK / Hold / Blocked)

### W2.3 — Move HSN/SAC Under Catalog
- Currently at `/settings/hsn-codes`
- Add to Catalog workspace tabs
- Keep settings link as redirect for backward compatibility

### W2.4 — Add Price List Comparison View
- New page or modal: Select 2 price lists side by side
- Table: Product | Standard Price | Promo Price | Difference | % Change
- Highlight price differences

### W2.5 — Enhance Product Detail
- Add section: "Stock by Branch" table (branch name, on_hand, reserved, available)
- Add section: "Recent Orders" (last 10 orders containing this product)
- Add section: "Price in Active Lists" (which price lists include this product, at what price)

---

## Mobile (Flutter) Tasks

### M2.1 — Set Up Drift Local Database
Create Drift database with initial tables:
```dart
// Tables for offline cache
class Retailers extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get code => text().nullable()();
  TextColumn get channel => text().nullable()();
  TextColumn get tier => text().nullable()();
  TextColumn get status => text()();
  RealColumn get outstanding => real().withDefault(const Constant(0))();
  RealColumn get creditLimit => real().withDefault(const Constant(0))();
  RealColumn get availableCredit => real().withDefault(const Constant(0))();
  RealColumn get overdueAmount => real().withDefault(const Constant(0))();
  IntColumn get overdueDays => integer().withDefault(const Constant(0))();
  TextColumn get creditStatus => text().withDefault(const Constant('ok'))();
  TextColumn get phone => text().nullable()();
  TextColumn get gstin => text().nullable()();
  DateTimeColumn get lastOrderDate => dateTime().nullable()();
  DateTimeColumn get lastPaymentDate => dateTime().nullable()();
  DateTimeColumn get lastVisitDate => dateTime().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
}

class Products extends Table {
  IntColumn get id => integer()();
  TextColumn get sku => text()();
  TextColumn get name => text()();
  TextColumn get categoryName => text().nullable()();
  TextColumn get unit => text()();
  RealColumn get gstRate => real()();
  RealColumn get defaultPrice => real().withDefault(const Constant(0))();
  IntColumn get stockAvailable => integer().withDefault(const Constant(0))();
  TextColumn get status => text()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
}

class PriceListItemsLocal extends Table {
  IntColumn get id => integer()();
  IntColumn get productId => integer()();
  IntColumn get priceListId => integer()();
  RealColumn get unitPrice => real()();
  IntColumn get minQty => integer().withDefault(const Constant(1))();
  RealColumn get discountPct => real().withDefault(const Constant(0))();
  DateTimeColumn get syncedAt => dateTime().nullable()();
}

class SyncMetadata extends Table {
  TextColumn get entityType => text()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  IntColumn get recordCount => integer().withDefault(const Constant(0))();
  
  @override
  Set<Column> get primaryKey => {entityType};
}
```

### M2.2 — Build Retailer Repository
- `RetailerRepository` with methods:
  - `searchRetailers(query)` — search local Drift DB first, fallback to API
  - `getRetailer(id)` — local first, API if not found or stale
  - `syncRetailers()` — pull from API, upsert into Drift
- `RetailerApi` — Dio calls to `/api/v1/customers`

### M2.3 — Build Retailer List Screen
- Search bar at top (searches local DB)
- Filter chips: All | Active | Blocked | Overdue
- Scrollable list of `OlListItem` cards:
  - Leading: first letter avatar with channel color
  - Title: retailer name
  - Subtitle: code + channel + tier
  - Trailing: outstanding amount (red if overdue) + credit status chip
- Pull-to-refresh triggers sync
- Tap → Retailer Profile

### M2.4 — Build Retailer Profile Screen
- **Header card:** Name, code, channel badge, tier badge, credit status chip (OK/HOLD/BLOCKED)
- **Credit banner (`OlCreditBanner`):** Outstanding ₹45,000 / Limit ₹1,00,000 | Overdue: ₹12,000 (15 days)
- **Quick info grid (2×2):**
  - Last Order: Mar 7
  - Last Payment: Mar 5
  - Last Visit: Mar 3
  - Overdue: 15 days
- **Contacts section:** List of contacts with tap-to-call
- **Addresses section:** Billing + shipping addresses
- **Bottom sticky bar:** "New Order" + "Quick Collect" buttons

### M2.5 — Build Product Repository
- `ProductRepository`:
  - `searchProducts(query, categoryId?)` — local DB search
  - `getProductsForOrder(customerId)` — with effective prices
  - `syncProducts()` — pull from API, upsert into Drift
- `ProductApi` — Dio calls to `/api/v1/products`

### M2.6 — Initial Sync on Login
- After successful login, trigger initial data sync:
  - Pull customers (assigned to this sales rep or all for the branch)
  - Pull products (all active)
  - Pull price list items (standard + applicable ones)
- Show progress indicator: "Syncing data... Customers (45/45) ✓ Products (120/120) ✓"
- Store sync timestamps in `SyncMetadata` table

---

## Migrations Needed
- None (backend changes are API-level only)

## API Changes
- Enhanced `GET /api/v1/customers/:id?include=credit_account,recent_orders,recent_payments`
- New `GET /api/v1/customers/:id/timeline`
- Enhanced `GET /api/v1/products?include=stock`

## Acceptance Criteria
- [ ] Customer detail page shows risk flags, outstanding banner, payment history tab, activity timeline
- [ ] Customer list has sortable Outstanding and Overdue columns
- [ ] HSN/SAC management accessible from Catalog workspace
- [ ] Price list comparison view works
- [ ] Product detail shows stock by branch and pricing info
- [ ] Flutter: Retailer list screen shows cached retailers with search
- [ ] Flutter: Retailer profile shows credit banner, contacts, quick info
- [ ] Flutter: Products cache loads on initial sync
- [ ] Flutter: Stale data warning shows if last sync > 2 hours ago

## Demo Scenarios Enabled After This Phase
- Customer detail page feels like a complete CRM profile with credit, orders, payments, timeline
- Sales rep on Flutter mobile can search retailers, see their credit status and outstanding before visiting
- Product catalog viewable on mobile with stock availability
- Price list comparison helps managers validate promotional pricing
