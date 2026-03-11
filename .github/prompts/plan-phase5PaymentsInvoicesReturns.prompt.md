# OrdWave — Phase 5: Payments + Invoices + Returns + Credit Notes

## Goal
Complete financial cycle. Accountant can manage collections, reconcile payments, generate invoices. Sales rep can collect on mobile.

**Duration:** ~2 weeks

## Modules Touched
- Payments (web enhancement + mobile build)
- Collection Schedules (NEW — backend + web + mobile)
- Invoices (web enhancement)
- Credit Notes (web enhancement)
- Advance Payments (web build)
- Returns (web enhancement)
- return_records deprecation completion

---

## Backend Tasks

### B5.1 — Create CollectionSchedule Model + Migration
```ruby
create_table :collection_schedules do |t|
  t.references :organization, null: false, foreign_key: true
  t.references :branch, null: false, foreign_key: true
  t.references :customer, null: false, foreign_key: true
  t.references :assigned_to, null: false, foreign_key: { to_table: :users }
  t.date :scheduled_date, null: false
  t.decimal :amount_expected, precision: 12, scale: 2, null: false
  t.string :status, null: false, default: 'planned'
  t.text :notes
  t.references :completed_payment, foreign_key: { to_table: :payments }
  t.date :rescheduled_to
  t.string :skip_reason
  t.timestamps
end

add_index :collection_schedules, [:assigned_to_id, :scheduled_date, :status],
  where: "status = 'planned'", name: 'idx_upcoming_collection_schedules'
add_index :collection_schedules, [:organization_id, :branch_id, :scheduled_date]
add_index :collection_schedules, [:customer_id, :scheduled_date]
```

### B5.2 — CollectionSchedule Model + Controller + Policy
```ruby
class CollectionSchedule < ApplicationRecord
  belongs_to :organization
  belongs_to :branch
  belongs_to :customer
  belongs_to :assigned_to, class_name: 'User'
  belongs_to :completed_payment, class_name: 'Payment', optional: true

  STATUSES = %w[planned completed partial skipped rescheduled].freeze

  validates :scheduled_date, presence: true
  validates :amount_expected, presence: true, numericality: { greater_than: 0 }
  validates :status, inclusion: { in: STATUSES }

  scope :for_date, ->(date) { where(scheduled_date: date) }
  scope :for_user, ->(user_id) { where(assigned_to_id: user_id) }
  scope :upcoming, -> { where(status: 'planned').where('scheduled_date >= ?', Date.current) }
  scope :overdue_planned, -> { where(status: 'planned').where('scheduled_date < ?', Date.current) }

  def complete!(payment)
    update!(status: 'completed', completed_payment: payment)
  end

  def skip!(reason)
    update!(status: 'skipped', skip_reason: reason)
  end

  def reschedule!(new_date)
    update!(status: 'rescheduled', rescheduled_to: new_date)
    # Create new schedule for the new date
    self.class.create!(
      organization: organization, branch: branch, customer: customer,
      assigned_to: assigned_to, scheduled_date: new_date,
      amount_expected: amount_expected, status: 'planned'
    )
  end
end
```

### B5.3 — CollectionSchedule Endpoints
```ruby
# GET    /api/v1/collection_schedules             — index (filter: date, assigned_to, status, customer_id)
# POST   /api/v1/collection_schedules             — create
# PATCH  /api/v1/collection_schedules/:id          — update
# POST   /api/v1/collection_schedules/:id/complete — mark completed, link payment
# POST   /api/v1/collection_schedules/:id/skip     — skip with reason
# POST   /api/v1/collection_schedules/:id/reschedule — reschedule to new date
```

### B5.4 — Auto-Generate Collection Schedules Job
Weekly cron job that creates collection schedules from overdue invoices:
```ruby
class GenerateCollectionSchedulesJob < ApplicationJob
  queue_as :low
  
  def perform(organization_id)
    org = Organization.find(organization_id)
    # Find all customers with overdue invoices
    overdue_customers = Customer.where(organization: org)
      .joins(:sales_invoices)
      .where(sales_invoices: { status: %w[issued partially_paid] })
      .where('sales_invoices.due_date < ?', Date.current)
      .distinct
    
    overdue_customers.each do |customer|
      # Skip if already has a planned schedule this week
      next if customer.collection_schedules.planned.where(scheduled_date: Date.current..7.days.from_now).exists?
      
      outstanding = customer.sales_invoices.where(status: %w[issued partially_paid]).sum(:outstanding_amount)
      assigned_to = customer.sales_rep || org.memberships.joins(:role).where(roles: { name: 'accountant' }).first&.user
      next unless assigned_to
      
      CollectionSchedule.create!(
        organization: org,
        branch: customer.branch,
        customer: customer,
        assigned_to: assigned_to,
        scheduled_date: next_business_day,
        amount_expected: outstanding,
        status: 'planned'
      )
    end
  end
end
```

### B5.5 — Enhance Payment Allocation Detail Endpoint
```ruby
# GET /api/v1/payments/:id
# Include: allocations with invoice details
# Response includes: payment details + allocations[{invoice_number, invoice_date, allocated_amount, invoice_total}]
# + advance_payments if any created
```

### B5.6 — Bulk Invoice Generation
```ruby
# POST /api/v1/sales_invoices/bulk_generate
# Body: { order_ids: [1, 2, 3] }  — orders must be in delivered/partial_delivery status
# Creates invoices for all specified orders
# Returns: { generated: 3, skipped: 0, errors: [] }
```

### B5.7 — Complete return_records Deprecation
- Add migration to remove `return_records` if all data migrated (from Phase 0)
- Remove `ReturnRecord` model
- Remove any controller/view references
- Update `TripStop` associations

---

## Web Tasks

### W5.1 — Build Collection Schedule Page
- New page: `/collections/schedule` (or tab in Finance workspace)
- **Calendar view:** Month calendar with dots on dates that have scheduled collections
- **List view:** Date-grouped list of planned collections
- Each item: Customer name, Expected amount, Assigned to, Status
- **Actions per item:**
  - "Collected" → opens create payment modal prefilled
  - "Skip" → reason dropdown → marks skipped
  - "Reschedule" → date picker → creates new schedule
- **Create Schedule:** Modal with customer picker, date, expected amount, assign to
- **Filters:** Date range, assigned to, status, customer

### W5.2 — Build Advance Payment Management Page
- New page: `/finance/advances` (or tab in Finance workspace)
- Table: Customer | Original Amount | Balance | Status | Source Payment # | Date
- **Actions:**
  - "Apply to Invoice" → modal: select invoice, enter amount (max: advance balance), apply
  - "Refund" → confirmation modal with reason
- **Filters:** Status (unapplied/partially_applied/applied/refunded), customer

### W5.3 — Enhance Payment Detail Page
- Add "Allocation Details" section:
  - Table: Invoice # | Invoice Date | Invoice Total | Allocated Amount
  - If unallocated amount > 0: "Advance payment created: ₹{amount}"
- Add payment reversal workflow:
  - "Reverse Payment" button (manager+ only)
  - Confirmation modal with mandatory reason text
  - Shows what will be affected: "This will reverse allocations to invoices: INV-001, INV-002"

### W5.4 — Enhance Credit Note Application UI
- On credit note detail page, add "Apply to Invoice" action:
  - Show unapplied amount available
  - Select invoice from dropdown (outstanding invoices for this customer)
  - Enter application amount (max: min(unapplied, invoice outstanding))
  - Confirm → creates CreditNoteApplication
- Show application history table: Invoice # | Applied Amount | Date | Applied By

### W5.5 — Bulk Invoice Generation Button
- On orders list page (filtered to delivered status):
  - "Generate Invoices for All" button
  - Confirmation: "Generate invoices for N delivered orders?"
  - Progress feedback, then result: "Generated N invoices, M skipped (already invoiced)"
- On order detail page: "Generate Invoice" button (already planned in W3.3)

### W5.6 — Invoice PDF Preview
- On invoice detail page, add "Preview PDF" button
- Opens inline PDF viewer (browser native or embedded)
- Alongside "Download PDF" button

### W5.7 — Collection Performance Dashboard (Insights)
- Enhance `/insights/collections` with:
  - Collection target vs actual bar chart (daily/weekly/monthly)
  - Collection by mode pie chart (cash/UPI/cheque/bank)
  - Top collectors ranking table
  - Overdue trend line (total overdue amount over time)

---

## Mobile (Flutter) Tasks

### M5.1 — Build Quick Collect Screen
Full payment collection flow:
1. **Select customer:** Search from local DB, recent customers shown
2. **Enter amount:** `OlAmountInput` with ₹ prefix, large numeric keypad
3. **Select mode:** Icon buttons — 💵 Cash | 📱 UPI | 📝 Cheque | 🏦 Bank Transfer
4. **Add reference (conditional):**
   - UPI: UPI reference number (text field)
   - Cheque: Cheque number + bank name + date
   - Bank transfer: Transaction reference
   - Cash: No reference needed
5. **Review summary:** Customer, amount, mode, reference → "Confirm Payment"
6. **Success:** Green animation + "₹12,000 collected from Sri Lakshmi Stores" → option to "Collect More" or "Done"

- Offline: Saved to `pending_payments` Drift table + sync queue
- Sync badge: "Pending sync" until confirmed on server

### M5.2 — Build Collection Schedule Screen
- Tab bar: Today | This Week | Overdue
- Each item card:
  - Customer name + expected amount
  - Overdue indicator if past scheduled date
  - Tap → opens Quick Collect prefilled
- "Skip" swipe action with reason picker
- Pull-to-refresh triggers sync
- Offline: Schedule cached from server, completions queued for sync

### M5.3 — Build Recent Collections List
- Scrollable list of recent payments (last 7 days)
- Each item: customer name, amount, mode, date, sync badge (synced/pending/failed)
- Tap → read-only detail view

### M5.4 — Update Sales Rep Home Screen
Now that collections are built, update home with real data:
- KPI cards pull from local DB: visits today, orders today, collections today
- "Collection Schedule" section shows next 3 upcoming collections
- "Collect" FAB navigates to Quick Collect

---

## Migrations Needed
1. `create_collection_schedules` — see B5.1
2. `drop_return_records` — finalize deprecation (if data migration from Phase 0 confirmed complete)

## API Changes
- New: `GET/POST /api/v1/collection_schedules`, `POST /complete`, `POST /skip`, `POST /reschedule`
- New: `POST /api/v1/sales_invoices/bulk_generate`
- Enhanced: `GET /api/v1/payments/:id` (include allocation details)

## Acceptance Criteria
- [ ] Collection schedule page shows calendar + list views
- [ ] Accountant can create, skip, reschedule collection schedules
- [ ] "Collected" on schedule opens prefilled payment modal
- [ ] Advance payment page shows all advances with apply/refund actions
- [ ] Payment detail shows allocation breakdown
- [ ] Payment reversal requires manager role + reason
- [ ] Credit note can be applied to invoices from CN detail page
- [ ] Bulk invoice generation works for delivered orders
- [ ] Invoice PDF preview shows inline
- [ ] Collection insights chart shows target vs actual
- [ ] Flutter: Quick collect flow works end-to-end (customer → amount → mode → confirm)
- [ ] Flutter: Collection works offline — queued for sync
- [ ] Flutter: Collection schedule shows today's planned collections
- [ ] Flutter: Home screen KPIs show real local data

## Demo Scenarios Enabled After This Phase
- **Collection workflow:** Accountant Lakshmi sees overdue customer → creates collection schedule for today → assigns to sales rep Rajan → Rajan sees schedule on mobile → visits customer → collects ₹25,000 UPI → enters reference → confirms → auto-allocated to oldest invoice → outstanding updated
- **Bulk invoicing:** Accountant clicks "Generate Invoices for All" on 5 delivered orders → 5 invoices created with PDF → sends to customers
- **Advance payment:** Customer pays ₹50,000 but only ₹40,000 outstanding → ₹10,000 advance created → accountant applies advance to next invoice
- **Credit note flow:** Return QC completed → credit note issued → accountant applies CN to outstanding invoice → customer balance adjusted
