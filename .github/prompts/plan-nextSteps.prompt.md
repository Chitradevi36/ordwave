You are working in the `orderlane_pro` monorepo (Rails 7.1 backend · Next.js 14 web · Flutter mobile_flutter).
Complete every task below in order. Use existing repo conventions: Pundit for authz, Drift for local Flutter DB, Riverpod for state, Shadcn + Tailwind for web UI.
Fix any failures you encounter before moving to the next task — do not skip.

---

# Sprint Close-Out & Next Steps

## Task 0 — Founder Demo Prep

Prepare a demo script covering every change shipped this sprint before merging to `main`.

### Demo table
| Area | What changed | Where to verify |
|------|-------------|----------------|
| Credit flow | Hold state → "Request Override" sheet | Mobile: place order for over-limit customer |
| Cart review | Outstanding balance + credit status shown pre-submit | Mobile: open cart for any customer |
| Payments sync | Pending payments push with idempotency key | Mobile: collect offline → go online → check server |
| Token refresh | Silent re-auth on 401 — no surprise logouts | Mobile: let token expire, make a request |
| Offline trips | Trip detail loads without network | Mobile: open trip → airplane mode → reopen |
| Sync center | Failed items discardable individually | Mobile: Sync Center → View & Discard Failed |
| Orders list | Rejection reason shown inline | Web: Orders → filter by rejected |
| Ageing report | No longer errors on overdue invoices | Web: Finance → Ageing Report |
| Audit log | Full trail with filters + pagination | Web: Settings → Audit & Security → Audit Log |
| Sidekiq UI | HTTP Basic Auth enforced | Set `SIDEKIQ_USER` / `SIDEKIQ_PASSWORD` env vars |

### Decisions needed from founder before next sprint
1. **Override notification channel** — should "Request Override" (credit hold) notify the manager via (a) in-app Sidekiq job, (b) ActionMailer email, or (c) push notification?
2. **Audit log retention** — auto-purge after how many months?
3. **Rejection reason editability** — can managers edit `cancellation_reason` post-rejection, or is it immutable?
4. **Duplicate payment alert** — if server detects idempotency_key collision on `POST /api/v1/payments`, who gets notified and how?

---

## Task 1 — Build the Pickup / Pick-Confirm Workflow

This is the only unbuilt item from the 10-premium-improvements list.

### User story
Warehouse staff mark a confirmed order as physically picked. A supervisor then confirms the pick before the order is eligible for dispatch.

### 1a — DB migration
Generate and run a migration adding to `sales_orders`:
- `pick_status` — PostgreSQL enum `pending_pick | picked | pick_confirmed`, default `pending_pick`
- `picked_by_id` integer FK → `users`, nullable
- `picked_at` datetime, nullable
- `pick_confirmed_by_id` integer FK → `users`, nullable
- `pick_confirmed_at` datetime, nullable

### 1b — Model (`app/models/sales_order.rb`)
```ruby
enum :pick_status, { pending_pick: 0, picked: 1, pick_confirmed: 2 }
belongs_to :picked_by,            class_name: 'User', optional: true
belongs_to :pick_confirmed_by,    class_name: 'User', optional: true
```

### 1c — Controller (extend `app/controllers/api/v1/pick_lists_controller.rb`)
Add member actions:
- `POST /api/v1/orders/:id/pick`
  - Guard: order must be `pending_pick`; return 422 otherwise
  - Sets `pick_status: :picked`, `picked_by: current_user`, `picked_at: Time.current`
  - Authorize: `policy(@order).pick?`
  - Returns updated order JSON
- `POST /api/v1/orders/:id/confirm_pick`
  - Guard: order must be `picked`; return 422 otherwise
  - Sets `pick_status: :pick_confirmed`, `pick_confirmed_by: current_user`, `pick_confirmed_at: Time.current`
  - Authorize: `policy(@order).confirm_pick?`
  - Returns updated order JSON

### 1d — Pundit (`app/policies/pick_list_policy.rb` — extend or create)
```ruby
def pick?          = user.warehouse_staff? || manager_above?
def confirm_pick?  = user.supervisor?      || manager_above?
```

### 1e — Routes (`config/routes.rb`)
Inside the orders/pick_lists resource block:
```ruby
member do
  post :pick
  post :confirm_pick
end
```

### 1f — Web UI
Find the order detail page (likely `web/app/orders/[id]/page.tsx`).
- Add a `PickStatusBadge`: `pending_pick` → gray "Awaiting Pick" · `picked` → amber "Picked" · `pick_confirmed` → green "Pick Confirmed"
- Show **"Mark as Picked"** button when `pick_status === 'pending_pick'` and current user has warehouse role
- Show **"Confirm Pick"** button when `pick_status === 'picked'` and current user has supervisor role
- On success: optimistically update the badge, show a Sonner toast

### 1g — Mobile (low priority, do last)
Surface `pick_status` as a read-only badge per order line on the delivery trip detail screen.

---

## Task 2 — Run verification checks

Run in sequence; fix all failures before moving on:

```bash
cd backend && bundle exec rspec spec/models/credit_note_spec.rb \
  spec/services/orders/submit_order_service_spec.rb \
  spec/controllers/api/v1/reports_controller_spec.rb

cd mobile_flutter && flutter analyze

cd web && npx tsc --noEmit
```

---

## Task 3 — Write missing specs

### `backend/spec/requests/api/v1/audit_logs_spec.rb`
- `GET /api/v1/audit_logs` → 200 for manager role, 403 for sales_rep role
- Filter by `auditable_type`, `action`, `date_from`/`date_to` — assert only matching records returned
- Pagination: response includes `meta.total_pages`, default `per_page: 25`

### `backend/spec/services/orders/submit_order_service_spec.rb` (add to existing)
- Concurrent credit evaluation: spin up two threads submitting for the same customer simultaneously; assert no double-spend (credit used ≤ credit limit after both resolve)

### `backend/spec/models/credit_note_spec.rb` (add or create)
- `build(:credit_note, return_request: nil)` → valid
- `build(:credit_note, customer: nil)` → invalid

### What to demo
| Area | What changed | Where to verify |
|------|-------------|----------------|
| Credit flow | Hold state now has "Request Override" sheet | Mobile: place order for over-limit customer |
| Cart review | Outstanding balance + credit status shown before submit | Mobile: open cart for any customer |
| Payments sync | Pending payments now push to server with idempotency | Mobile: collect offline → go online → check server |
| Token refresh | Silent re-auth on 401 — no more surprise logouts | Mobile: let token expire naturally |
| Offline trips | Trip detail loads without network | Mobile: open trip, airplane mode, reopen |
| Sync center | Failed items can be individually discarded | Mobile: Sync Center → View & Discard Failed |
| Orders list | Rejection reason shown inline on rejected orders | Web: Orders page, filter by rejected |
| Ageing report | No longer errors on overdue invoices | Web: Finance → Ageing Report |
| Audit log | Full audit trail with filters | Web: Settings → Audit & Security → Audit Log |
| Sidekiq UI | Now password-protected | `SIDEKIQ_USER` / `SIDEKIQ_PASSWORD` env vars |

### Open questions for founder
- Should the "Request Override" notification go to the manager via push, email, or Sidekiq job?
- Audit log retention policy — how many months to keep?
- Should rejected order reasons be editable after the fact?
- Who should receive the idempotency-key collision alert if a duplicate payment is detected server-side?
