# OrdWave — Phase 6: Notifications + Settings + Reports Polish

## Goal
Notification system fully wired. Settings pages complete. Reports and insights actionable. Beat management operational.

**Duration:** ~1.5 weeks

## Modules Touched
- Notifications (complete wiring)
- Settings (web enhancement)
- Reports/Insights (web enhancement)
- Beat Management (web + mobile)
- Visit Logs (mobile build)
- Push Notifications (mobile)
- Exports (web enhancement)

---

## Backend Tasks

### B6.1 — Wire All Remaining Notification Triggers
Add `Notifications::CreateService` calls to these services (not yet covered):

**Order events (covered in Phase 1):** ✅ Already done

**Delivery events:**
- `Delivery::DispatchTripService` → notify driver: "Trip #{trip.code} dispatched — #{trip.stops.count} stops"
- `Delivery::CompleteStopService` → notify order creator on delivery: "Order #{order.number} delivered to #{customer.name}"
- `Delivery::CompleteStopService` (failure) → notify manager: "Delivery failed at #{customer.name} — #{exception_code}"

**Payment events (covered in Phase 1 partially):**
- `Payments::ReversePaymentService` → notify original creator + accountants: "Payment #{payment.reference} reversed"

**Credit events:**
- `Credit::UpdateCreditPolicyService` (on limit change) → notify sales reps for that customer: "Credit limit for #{customer.name} changed to ₹#{new_limit}"
- `Credit::BlockCustomerService` → notify sales reps: "#{customer.name} credit blocked"
- `CreditLimitChangeRequests::CreateService` → notify managers/admins: "Credit limit change requested for #{customer.name}"
- `CreditLimitChangeRequests::DecideService` (approve/reject) → notify requester: "Credit limit request #{approved/rejected}"

**Inventory events:**
- `StockTransfers::DispatchService` → notify receiving branch warehouse staff: "Stock transfer #{transfer.number} dispatched"
- `StockTransfers::ReceiveService` → notify sending branch: "Stock transfer #{transfer.number} received"
- Low stock alert (already built in Phase 4 B4.5)

**Return events:**
- `Returns::SubmitReturnService` → notify warehouse staff: "Return #{return_request.number} submitted for QC"
- `Returns::CompleteQcService` → notify accountant + creator: "Return QC complete — #{approved_count} approved"
- `CreditNotes::CreateService` → notify customer-facing sales rep: "Credit note #{cn.number} issued for #{customer.name}"

**Beat events:**
- `Beats::AssignBeatService` → notify sales rep: "Beat plan assigned for #{date} — #{beat.customer_count} customers"

### B6.2 — Push Notification Service Enhancement
```ruby
class Notifications::PushService
  def initialize(user, title, body, deep_link: nil)
    @user = user
    @title = title
    @body = body
    @deep_link = deep_link
  end

  def deliver_later
    PushNotificationJob.perform_later(@user.id, @title, @body, @deep_link)
  end
end

class PushNotificationJob < ApplicationJob
  queue_as :default

  def perform(user_id, title, body, deep_link)
    user = User.find(user_id)
    tokens = user.device_tokens.where(active: true)
    return if tokens.empty?

    # FCM integration (placeholder — actual implementation depends on gem)
    tokens.each do |token|
      # Send via Firebase Cloud Messaging
      FcmClient.send(
        token: token.token,
        notification: { title: title, body: body },
        data: { deep_link: deep_link }.compact
      )
    rescue StandardError => e
      Rails.logger.warn "Push notification failed for token #{token.id}: #{e.message}"
      token.update!(active: false) if e.is_a?(FcmClient::InvalidTokenError)
    end
  end
end
```

### B6.3 — Organization Settings Endpoints Enhancement
Ensure full CRUD for:
```ruby
# GET /api/v1/organizations/:id/settings     — get all settings
# PATCH /api/v1/organizations/:id/settings   — update settings

# Settings include:
# {
#   general: { name, address, phone, email, gstin, pan, logo_url },
#   invoicing: { invoice_prefix, auto_generate_on_delivery, payment_terms_days },
#   credit: { default_credit_limit, default_credit_days, auto_block_overdue_days },
#   notifications: { email_on_order, sms_on_delivery, push_enabled },
#   inventory: { low_stock_threshold_percentage, auto_reserve_on_approval },
#   reports: { fiscal_year_start_month, currency_locale }
# }
```

### B6.4 — Beat Schedule + Visit Log Endpoints
Ensure mobile-friendly endpoints:
```ruby
# GET /api/v1/beat_schedules?date=2026-03-10&assigned_to=me
# Returns beat with customer list for the day, including:
# - Customer name, address (for navigation)
# - Last visit date, last order date
# - Outstanding amount
# - Visit status (pending/checked_in/checked_out/skipped)

# POST /api/v1/visit_logs — create visit (check-in)
# Body: { customer_id, latitude, longitude, check_in_time }

# PATCH /api/v1/visit_logs/:id — complete visit (check-out)  
# Body: { check_out_time, latitude, longitude, visit_type, notes, order_id?, payment_id? }
```

### B6.5 — Report Data Endpoints
Ensure these analytics endpoints exist:
```ruby
# GET /api/v1/reports/sales_summary?period=monthly&from=2026-01-01&to=2026-03-31
# GET /api/v1/reports/collection_summary?period=weekly&assigned_to=12
# GET /api/v1/reports/product_performance?category_id=5&period=monthly
# GET /api/v1/reports/customer_wise_outstanding
# GET /api/v1/reports/sales_rep_performance
# GET /api/v1/reports/delivery_performance
# GET /api/v1/reports/ageing_report
```

---

## Web Tasks

### W6.1 — Complete Settings Pages
Ensure all settings sections fully functional:

**Organization Settings (`/settings/general`):**
- Business name, address, contact details, GSTIN, PAN, logo upload
- All fields editable with validation

**Branch Management (`/settings/branches`):**
- CRUD for branches with address, manager assignment
- Active/inactive toggle

**Team Management (`/settings/team`):**
- Invite user (email, role, branch assignment)
- Edit role/branch assignment
- Deactivate user (soft delete)
- Resend invite

**Credit Policy Settings (`/settings/credit-policy`):**
- Default credit limit, credit days
- Auto-block threshold (days overdue)
- Auto-invoice trigger (on_delivery / manual)
- Collection-first warning threshold

**Invoice Settings (`/settings/invoices`):**
- Invoice number prefix
- Payment terms (default days)
- Invoice template selection (if applicable)
- Auto-generate on delivery toggle

**Notification Preferences (`/settings/notifications`):**
- Per-notification-type toggle: email, push, in-app
- List of notification types with toggle switches
- Save preferences to user or org level

### W6.2 — Enhance Insights/Dashboard with Real Charts
Ensure Recharts-based analytics on `/insights`:

**Sales Performance:**
- Revenue trend line chart (daily/weekly/monthly toggle)
- Order count bar chart
- Average order value trend
- Top 10 customers by revenue (horizontal bar)
- Top 10 products by quantity (horizontal bar)

**Collection Performance:**
- Collection target vs actual (stacked bar)
- Payment mode distribution (pie/donut)
- Collection cycle trend (days)
- Overdue amount trend line

**Delivery Performance:**
- First-attempt delivery rate (%)
- Returns rate trend
- Average stops per trip
- Exception breakdown (pie chart)

### W6.3 — Export Enhancement
- Add "Export" button to all list pages (Orders, Customers, Invoices, Payments, Products, Inventory)
- Export modal: Select format (CSV, Excel), Select columns, Date range filter
- Uses existing `Export` model + background job
- Show export history with download links on `/settings/exports`

### W6.4 — Beat Management Page
- New page: `/sales/beats` or tab in Sales workspace
- **Beat list:** Table with beat name, area, customer count, assigned sales rep, day of week
- **Beat detail:** Map (if possible) or list of customers in route order
- **Assign beats:** Drag customers between beats, or multi-select + assign
- **Beat calendar:** Weekly calendar showing beat assignments per sales rep

---

## Mobile (Flutter) Tasks

### M6.1 — Build Beat Plan Screen (Sales Rep)
- "Today's Beat" tab shows beat customers in route order:
  - Customer name, address (short), visit status badge, outstanding
  - Icons: ✓ (visited), ● (current), ○ (pending)
- "Navigate to Next" button → opens device maps for next unvisited customer
- Tap customer → options: Check In | View Profile | New Order | Quick Collect

### M6.2 — Build Check-In / Check-Out Flow
**Check In:**
- Tap "Check In" on beat plan or customer profile
- Capture GPS coordinates (background permission with graceful fallback)
- If GPS distance from customer address > 500m: "You seem far from {customer name}. Check in anyway?"
- Record check_in_time, lat/long → save locally + queue for sync

**Check Out:**
- After visiting (or after creating order/collection), tap "Check Out"
- Select visit outcome: Ordered | Collected | Both | No Order (with reason)
- Optional: Notes text field
- Record check_out_time, outcome → update local visit log → queue for sync

### M6.3 — Set Up Push Notifications (FCM)
- Integrate `firebase_messaging` (or `firebase_cloud_messaging`) package
- On login: register device token → `POST /api/v1/device_tokens`
- On logout: deactivate device token
- Handle notification tap → parse deep_link → navigate via GoRouter
- Show in-app notification banner for foreground notifications

### M6.4 — Build Notification Inbox Screen
- Scrollable list of notifications (from local cache + API)
- Notifications grouped: Today | Yesterday | Earlier
- Each item: icon (based on type), title, body snippet, time ago, read status dot
- Swipe to dismiss
- Tap → navigate to deep_link
- "Mark all as read" button in app bar
- Badge count on bottom nav / app bar bell icon

### M6.5 — Build Sync Center Screen
Accessible from Settings → Sync Status:
- **Last sync:** "Customers: synced 2 min ago, Products: synced 5 min ago"
- **Pending operations:** List of queued operations with: type, entity name, created time
  - Tap to see detail
  - Swipe to retry (if failed)
- **Force sync** button: Triggers immediate full delta sync
- **Clear cache** button: With confirmation warning

---

## Migrations Needed
- None (all models exist from previous phases)

## API Changes
- Enhanced: Organization settings CRUD
- Ensured: Beat schedule, visit log endpoints exist and are mobile-friendly
- New: Report data endpoints (7 report types)

## Acceptance Criteria
- [ ] All 20+ notification triggers fire correctly and create in-app notifications
- [ ] Push notifications reach mobile device via FCM
- [ ] All settings pages are complete and functional
- [ ] Insights page shows real charts with data from report endpoints
- [ ] Export button works on all list pages
- [ ] Beat management page allows CRUD of beats and assignments
- [ ] Flutter: Sales rep sees beat plan with visit status for each customer
- [ ] Flutter: Check-in records GPS + time, check-out records outcome
- [ ] Flutter: Push notifications appear in-app and in system tray
- [ ] Flutter: Notification inbox shows grouped, dismissible notifications
- [ ] Flutter: Sync center shows status and allows force sync

## Demo Scenarios Enabled After This Phase
- **Full beat workflow:** Rajan sees today's beat (8 customers) → navigates to first → checks in (GPS captured) → creates order → collects payment → checks out ("Both: Ordered + Collected") → moves to next customer → beat completion tracked
- **Notification flow:** Rajan submits order → Priya (manager) gets push notification "New order ₹15,000 from Sri Lakshmi needs approval" → taps → opens order detail on web → approves → Rajan gets notification "Order approved"
- **Insights driven decisions:** Manager views sales performance → sees revenue dipping in Zone B → checks beat compliance → reassigns underperforming beats
- **Settings customization:** Admin configures auto-invoice on delivery, sets credit policy defaults, customizes notification preferences
