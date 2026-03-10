# OrderLane Pro — Phase 1: Core Role/Navigation Foundation

## Goal
Role-based experience works end-to-end on web. Notification infrastructure exists. Flutter login + role-based home screen functional.

**Duration:** ~1 week

## Modules Touched
- Notifications (NEW)
- Auth (mobile)
- Dashboard (all roles)
- Navigation (web + mobile)
- Approvals (web)

---

## Backend Tasks

### B1.1 — Create Notification Model + Migration
```ruby
# Migration
create_table :notifications do |t|
  t.references :organization, null: false, foreign_key: true
  t.references :user, null: false, foreign_key: true          # recipient
  t.references :actor, foreign_key: { to_table: :users }      # who triggered it
  t.string :notifiable_type                                     # polymorphic
  t.bigint :notifiable_id
  t.string :notification_type, null: false                      # enum
  t.string :title, null: false
  t.text :body
  t.string :deep_link_url
  t.string :severity, default: 'medium'                         # low, medium, high
  t.datetime :read_at
  t.datetime :dismissed_at
  t.timestamps
end

add_index :notifications, [:user_id, :read_at], where: "read_at IS NULL", name: 'idx_unread_notifications'
add_index :notifications, [:user_id, :organization_id, :created_at]
add_index :notifications, [:notifiable_type, :notifiable_id]
```

### B1.2 — Notification Model
```ruby
class Notification < ApplicationRecord
  belongs_to :organization
  belongs_to :user          # recipient
  belongs_to :actor, class_name: 'User', optional: true
  belongs_to :notifiable, polymorphic: true, optional: true

  TYPES = %w[
    order_submitted order_approved order_rejected order_held
    credit_blocked delivery_completed delivery_failed
    payment_confirmed payment_reversed
    stock_low transfer_dispatched transfer_received
    limit_change_requested limit_change_decided
    return_submitted credit_note_issued
    beat_assigned invoice_generated trip_assigned
  ].freeze

  validates :notification_type, inclusion: { in: TYPES }
  validates :title, presence: true
  validates :severity, inclusion: { in: %w[low medium high] }

  scope :unread, -> { where(read_at: nil) }
  scope :not_dismissed, -> { where(dismissed_at: nil) }
  scope :recent, -> { order(created_at: :desc).limit(50) }
  scope :by_type, ->(type) { where(notification_type: type) }
  scope :high_priority, -> { where(severity: 'high') }

  def read?
    read_at.present?
  end

  def mark_read!
    update!(read_at: Time.current) unless read?
  end
end
```

### B1.3 — Notifications Controller
```ruby
# Api::V1::NotificationsController
# GET    /notifications          — index (filterable: unread, type, severity)
# PATCH  /notifications/:id/read — mark single as read
# POST   /notifications/read_all — mark all as read
# DELETE /notifications/:id      — dismiss
```

### B1.4 — Notification Policy
- All users can see their own notifications only
- No cross-user notification access
- Only own notifications can be read/dismissed

### B1.5 — NotificationService
```ruby
class Notifications::CreateService
  def initialize(organization:, recipients:, actor:, notifiable:, type:, title:, body: nil, deep_link: nil, severity: 'medium')
    # ...
  end

  def call
    recipients.each do |user|
      Notification.create!(
        organization: organization,
        user: user,
        actor: actor,
        notifiable: notifiable,
        notification_type: type,
        title: title,
        body: body,
        deep_link_url: deep_link,
        severity: severity
      )
    end
    # Queue push notification job for each recipient with device tokens
    recipients.each { |u| Notifications::PushService.new(u, title, body).deliver_later }
  end
end
```

### B1.6 — Wire First Notification Triggers
Add notification creation calls to these existing services:
- `Orders::SubmitOrderService` → notify branch managers
- `Orders::ApproveOrderService` → notify order creator + warehouse
- `Orders::HoldOrderService` → notify order creator
- `Payments::ConfirmPaymentService` → notify accountants
- `Delivery::CompleteStopService` (on trip completion) → notify accountants

### B1.7 — Approvals Aggregate Endpoint
```ruby
# GET /api/v1/approvals
# Returns:
# {
#   data: {
#     held_orders: [...],         # SalesOrder.where(status: :on_hold)
#     credit_requests: [...],     # CreditLimitChangeRequest.where(status: :pending)
#     total_count: N
#   }
# }
```

---

## Web Tasks

### W1.1 — Wire NotificationsPanel to Real API
- Replace hardcoded mock data in `NotificationsPanel.tsx` with `useNotifications` React Query hook
- Add unread count badge on bell icon in TopBar
- Add "Mark all read" button
- Add click handler to navigate to `deep_link_url` on notification click
- Add empty state: "All caught up! No new notifications."

### W1.2 — Build Approval Inbox Page
- Create `web/app/approvals/page.tsx` (or enhance existing `/approvals/credit-limits`)
- Tab bar: All | Orders on Hold | Credit Limit Requests
- Each item renders as `ApprovalCard` component with:
  - Entity summary (order #, customer, amount OR credit request details)
  - Requestor name + timestamp
  - Approve / Reject buttons
  - Reason text field (required for reject, optional for approve)
- One-click approve without leaving the page (mutation + refetch)

### W1.3 — Enhance Role-Based Dashboards
- **Manager dashboard:** Add "Pending Approvals" count card linked to `/approvals`. Add "Active Trips" card. Add "Low Stock Items" count card
- **Accountant dashboard:** Add "Outstanding by Ageing" horizontal bar chart. Add "Today's Collections" amount
- **Warehouse dashboard:** Add "Orders to Pick" count (approved orders without delivery trips). Add "Incoming Transfers" count
- **Driver dashboard:** Add "Today's Trip" card with stop progress. Add "Next Stop" card with customer name + address

### W1.4 — Add Notification Count to Sidebar
- Show red dot / count badge next to "Sales" workspace label when there are held orders (for managers)
- Show badge next to bell icon for unread notification count

---

## Mobile (Flutter) Tasks

### M1.1 — Build Login Screen
- Email + password fields
- "Sign In" button with loading state
- Error display (invalid credentials, network error)
- On success: store JWT token in flutter_secure_storage, store user JSON in shared_preferences
- Navigate to home

### M1.2 — Build Role-Based Home Screen
- Router checks user role from stored profile
- Routes to appropriate home:
  - `sales_rep` → `SalesRepHome`
  - `driver` → `DriverHome`
  - Others → generic home with message "Use web app for full access"

### M1.3 — Build Sales Rep Home Screen
- Greeting text ("Good morning, {firstName}")
- KPI row: 3 cards (Visits Today: 0/8, Orders: ₹0, Collections: ₹0)
- "Today's Beat" section header + empty list placeholder
- FAB: "New Order" (disabled/coming soon for now)
- Sync indicator in app bar

### M1.4 — Build Driver Home Screen  
- Trip summary card (or "No trip assigned today" empty state)
- "Start Trip" button (disabled for now)
- Stop count indicator

### M1.5 — Build Settings/Profile Screen
- User name, email, role, branch display
- Logout button (clears tokens, navigates to login)
- App version display

### M1.6 — Build Bottom Navigation
- Sales Rep: `Home | Beat Plan | New Order | Collections | More`
  - Beat Plan, New Order, Collections → placeholder screens with "Coming Soon"
  - More → Settings
- Driver: `Home | My Trip | Collect | More`
  - My Trip, Collect → placeholder screens
  - More → Settings

---

## Migrations Needed
1. `create_notifications` — the notification table (see B1.1)

## API Changes
- `GET /api/v1/notifications` (new)
- `PATCH /api/v1/notifications/:id/read` (new)
- `POST /api/v1/notifications/read_all` (new)
- `DELETE /api/v1/notifications/:id` (new)
- `GET /api/v1/approvals` (new aggregate endpoint)

## Acceptance Criteria
- [ ] Submitting an order creates a notification for the branch manager
- [ ] Approving an order creates notifications for creator and warehouse
- [ ] Web bell icon shows unread count from real API
- [ ] Clicking a notification navigates to the relevant page
- [ ] Approval inbox shows held orders + credit limit requests
- [ ] Manager can approve/reject orders from the approval inbox without navigating away
- [ ] Each role sees appropriate dashboard cards on login
- [ ] Flutter app: login → role-based home → logout flow works
- [ ] Flutter app: bottom navigation renders correctly per role

## Demo Scenarios Enabled After This Phase
- Manager logs in → sees "3 Pending Approvals" → clicks → approves order → notification appears for sales rep
- Notification bell shows real-time count of unread alerts
- Flutter mobile app: sales rep can log in, see branded home screen with KPI placeholders
- Flutter mobile app: driver can log in, see trip-focused home screen
