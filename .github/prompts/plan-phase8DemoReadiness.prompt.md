# OrdWave — Phase 8: Demo-Readiness + Production-Hardening

## Goal
Product is demo-ready with seed data, error-proof, performant, and visually polished. Quick wins for wow-factor.

**Duration:** ~1 week

## Modules Touched
- Seed Data (comprehensive)
- Error Handling (global)
- Performance (monitoring + tuning)
- Visual Polish (web + mobile)
- Demo Script Preparation

---

## Backend Tasks

### B8.1 — Comprehensive Demo Seed Data
Create `db/seeds/demo_seeds.rb` with:

**Organization: Kannan Rice Distributors**
- 2 branches: Chennai Main, Coimbatore Branch
- 7 team members (one per role with memorable names):
  - Kannan (Owner) — kannan@demo.orderlanepro.dev / demo1234
  - Priya (Admin) — priya@demo.orderlanepro.dev / demo1234
  - Senthil (Manager) — senthil@demo.orderlanepro.dev / demo1234
  - Rajan (Sales Rep) — rajan@demo.orderlanepro.dev / demo1234
  - Kumar (Warehouse) — kumar@demo.orderlanepro.dev / demo1234
  - Lakshmi (Accountant) — lakshmi@demo.orderlanepro.dev / demo1234
  - Muthu (Driver) — muthu@demo.orderlanepro.dev / demo1234

**Customers (30):** Mix of channels/tiers with realistic Tamil names:
- 10 Kiranas (tier A: 3, B: 5, C: 2)
- 8 Supermarkets (tier A: 5, B: 3)
- 5 Wholesale shops
- 4 Hotels/Restaurants
- 3 Institutional buyers
- Credit limits: ₹25,000 to ₹5,00,000
- 5 customers with overdue balances, 2 blocked, 3 on hold

**Products (50):** Rice varieties + related FMCG:
- 15 rice types (Ponni, Sona Masuri, Basmati, etc.) in 5kg, 10kg, 25kg bags
- 10 dals/pulses
- 10 oils
- 10 spices
- 5 others
- All with HSN codes, GST rates (5%, 12%, 18%)

**Price Lists (3):** Standard, Wholesale Discount (10% off), Festival Special (15% off)

**Orders (50):** Spread across statuses for realistic feel:
- 10 delivered, 8 dispatched, 12 approved, 5 on_hold, 10 submitted, 5 draft
- Dated across last 30 days

**Payments (30):** Mix of modes:
- 15 cash, 8 UPI, 5 cheque, 2 bank transfer
- 25 confirmed, 3 pending, 2 reversed

**Delivery Trips (10):**
- 3 completed (with PODs), 2 in_progress, 3 planned, 2 draft
- Trips with 3-6 stops each

**Invoices (20):** Mix of statuses
**Credit Notes (5):** From returns
**Return Requests (8):** Mix of stages
**Beat Schedules:** 5 beats with customer assignments for the week
**Notifications (20):** Unread for demo

### B8.2 — API Performance Audit
- Add `rack-mini-profiler` for endpoint timing (dev/staging only)
- Audit N+1 queries: Add `.includes()` to all endpoints that join associations
- Key endpoints to verify:
  - `GET /api/v1/sales_orders` (with lines, customer) — must be < 200ms
  - `GET /api/v1/customers` (with credit_account) — must be < 200ms
  - `GET /api/v1/delivery_trips/:id` (with stops, orders, customer) — must be < 300ms
  - `GET /api/v1/sync/delta` — must be < 500ms for typical payload
  - `GET /api/v1/reports/sales_summary` — must be < 1000ms

### B8.3 — Add Request Rate Limiting
```ruby
# config/initializers/rack_attack.rb
# Already exists but verify/enhance:
# - Login: 5 attempts per 30 seconds per IP
# - API: 100 requests per minute per user
# - Sync push: 10 requests per minute per user
# - Exports: 5 per hour per user
```

### B8.4 — Health Check Endpoint Enhancement
```ruby
# GET /health
# Returns:
# {
#   status: "healthy",
#   version: "1.0.0",
#   timestamp: "2026-03-10T12:00:00Z",
#   services: {
#     database: "connected",
#     redis: "connected",
#     sidekiq: "running (3 workers)"
#   }
# }
```

---

## Web Tasks

### W8.1 — Visual Polish Pass
Go through all pages and ensure:

**Consistent spacing:** All page containers use `max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6`

**Loading skeletons:** Replace all `<p>Loading...</p>` with proper skeleton components:
- Table skeleton: 5 rows of pulsing bars
- Card skeleton: rectangle with header and body bars
- Chart skeleton: pulsing rectangle
- Form skeleton: labeled bars

**Empty states:** Replace all "No results" text with:
- Illustration (from lucide-react icon set at 48px)
- Descriptive text
- CTA button (if applicable)

**Error states:** Replace all `<p>Error</p>` with:
- Error icon
- "Something went wrong" message
- Retry button
- "Contact Support" link (if persistent)

**Responsive spot-check:**
- Dashboard: 3-column → 2 → 1 on mobile
- Tables: horizontal scroll on mobile
- Forms: full width on mobile
- Modals: full-screen on mobile

### W8.2 — Onboarding Flow Polish
- Ensure 6-step onboarding is visually polished:
  - Step indicators (numbered circles with lines)
  - Form validation with real-time feedback
  - "Skip for now" option on optional steps
  - Welcome screen on completion with role-appropriate next steps

### W8.3 — Dashboard Data Validation
For each role dashboard, ensure:
- All numbers use real API calls (no hardcoded mock data)
- Loading states while fetching
- Error boundary per card (one card error doesn't break whole dashboard)
- Proper empty states (new org with no data should show informative zero states)

### W8.4 — Meta + SEO Basics
- Page titles for each route (via Next.js metadata)
- Proper favicon
- Open Graph meta (for sharing login page link)
- manifest.json for PWA potential

### W8.5 — Keyboard Shortcuts (Quick Win)
- `Ctrl+K` or `Cmd+K`: Open search/command palette (future feature stub — show "Coming Soon")
- `Ctrl+N`: New order
- `Escape`: Close open modals/drawers

---

## Mobile (Flutter) Tasks

### M8.1 — Visual Polish Pass
- Review all screens against design tokens
- Ensure consistent padding (16dp edges, 12dp between cards)
- Verify all status chips use correct colors from `OlColors`
- Ensure all amounts use `₹` with Indian number system formatting (₹1,25,000)
- Test on small phone (5" screen) and tablet (10" screen)

### M8.2 — Screen Transition Animations
- Page transitions: `FadeTransition` for push, `SlideTransition` for bottom sheets
- List item animations: `AnimatedList` for adding/removing items
- Success animations: Lottie green checkmark on order submission, payment collection
- Pull-to-refresh: Branded refresh indicator with logo

### M8.3 — App Icon + Splash Screen
- Design app icon: OrdWave logo (green) on white background
- Generate adaptive icon for Android
- Generate iOS app icon
- Native splash screen: Brand color (#1B4332) background + white logo
- Transition to Flutter splash with loading indicator

### M8.4 — Demo Mode Toggle
- In settings, hidden toggle (tap version number 5 times to reveal)
- Demo mode pre-fills login with `rajan@demo.orderlanepro.dev` / `demo1234`
- Shows banner: "DEMO MODE" at top of app
- Can switch between demo roles

### M8.5 — Force Update + Maintenance Mode
```dart
class AppVersionService {
  Future<void> checkVersion() async {
    final response = await _api.get('/health');
    final minVersion = response.data['min_mobile_version'];
    
    if (currentVersion < minVersion) {
      showForceUpdateDialog();
    }
    
    if (response.data['maintenance_mode'] == true) {
      showMaintenanceScreen();
    }
  }
}
```

---

## Demo Script: "A Day in the Life of Kannan Rice Distributors"

### Scene 1: Owner Morning Overview (Web — Kannan)
1. Login as Kannan (owner) → Dashboard
2. See KPI cards: Today's Orders ₹1,50,000 | Outstanding ₹12,00,000 | Collections ₹85,000
3. Check notification bell: "3 orders awaiting approval", "Low stock: Ponni Raw Rice 25kg"
4. Click outstanding → drills to ageing report

### Scene 2: Manager Approves Orders (Web — Senthil)
1. Switch to Senthil (manager) → Dashboard shows "5 Pending Approvals"
2. Open Approval Inbox → see 3 held orders + 2 credit limit requests
3. Review first order: Sri Lakshmi Stores, ₹25,000, credit OK → Approve
4. Second order: Murugan Traders, ₹50,000, overdue ₹15,000 → Reject with note "Collect overdue first"
5. Credit request: Increase Sri Ganesh from ₹2L to ₹3L → Approve

### Scene 3: Sales Rep Field Work (Mobile — Rajan)
1. Open Flutter app, login as Rajan → Sales Rep Home
2. See today's beat: 8 customers, 0 visited
3. First customer: Sri Lakshmi Stores → Check In (GPS captured)
4. Create order: 10 × Ponni Raw 25kg + 5 × Sona Masuri 10kg = ₹22,500
5. Credit check → GREEN → Submit → Order #1248 created
6. Quick Collect: ₹15,000 UPI (reference: UTR123456)
7. Check Out → "Ordered + Collected" → Move to next customer
8. At difficult customer: Overdue ₹45,000 → Credit BLOCKED → Collect ₹25,000 cash → Then create order → Credit check → HOLD → "Submit anyway (needs approval)"

### Scene 4: Warehouse Processing (Web — Kumar)
1. Switch to Kumar (warehouse) → Dashboard shows "4 orders to pick"
2. Open pick list → Start picking → Check off items → Complete
3. View delivery trips → Create new trip: assign vehicle, add 5 stops
4. Dispatch trip → assigned to driver Muthu

### Scene 5: Driver Delivery (Mobile — Muthu)
1. Switch to Muthu (driver) on Flutter → Driver Home shows "Trip #045: 5 stops"
2. Start Trip → Navigate to first stop
3. Stop 1: Full delivery → Photo POD → ✓
4. Stop 2: Partial delivery (2 bags damaged) → returns captured → Signature POD → ✓
5. Stop 3: Failed (customer closed) → "Closed" exception → Skip → Continue
6. Complete remaining stops → Trip Complete → Summary: 4/5 delivered, ₹42,000 collected

### Scene 6: Accountant End of Day (Web — Lakshmi)
1. Switch to Lakshmi (accountant) → Dashboard shows "Today: ₹85,000 collected"
2. Generate invoices for delivered orders (bulk)
3. View collection performance chart
4. Process return → approve QC → issue credit note ₹3,500
5. Apply credit note to customer's outstanding invoice
6. Review ageing report → schedule collections for overdue customers

### Scene 7: Offline Resilience (Mobile — Rajan)
1. Rajan goes offline (airplane mode demonstration)
2. Search retailer from cached data → works instantly
3. Create order → saved locally with "Pending Sync" badge
4. Collect payment → saved locally
5. Come online → watch sync happen: 2 operations complete → green badges
6. Show sync center: "All synced ✓"

### Scene 8: Insights Review (Web — Kannan)
1. Back as Kannan → Insights
2. Revenue trend: ₹18L this month (↑15% vs last month)
3. Top products: Ponni Raw 25kg dominates
4. Collection performance: 85% target achieved
5. Sales rep leaderboard: Rajan top performer
6. Export monthly report → CSV downloaded

---

## Acceptance Criteria
- [ ] Demo seed data creates a realistic, explorable dataset
- [ ] All 30 demo customers with credit accounts and history
- [ ] All pages have loading skeletons, empty states, error states
- [ ] No hardcoded mock data anywhere in the web app
- [ ] Dashboard numbers come from real API calls
- [ ] Mobile app has proper icon, splash screen, and consistent styling
- [ ] Demo script can be performed end-to-end without errors
- [ ] All 8 demo scenes complete successfully
- [ ] API response times within stated limits
- [ ] Rate limiting configured for production
- [ ] Health check endpoint returns service status

## Sign-Off Checklist
- [ ] All 8 phases complete
- [ ] Full demo script rehearsed 3+ times
- [ ] Zero known crashes in critical paths
- [ ] Offline sync tested with 10+ operations
- [ ] Performance benchmarks met
- [ ] Security: JWT expiry, rate limiting, input validation confirmed
- [ ] Data: Demo seed idempotent (can re-run without duplicates)
