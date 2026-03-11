# OrdWave — Permissions & State Machine Plan

## 7. Permissions and State Machine Plan

### 7.1 Authorization Architecture

**Current:** Pundit policies with `UserContext(user, organization)` struct as `pundit_user`. 51 policy files. `ApplicationPolicy` base with role helpers.

**Enhancements needed:**

1. **Branch scoping in policies** — Currently policies check `member?` (org membership). Need to also enforce branch-level scoping for branch-specific roles (manager, warehouse_staff, driver, sales_rep). The membership model already tracks branch assignment.

2. **Ownership scoping** — Sales reps should only see their own orders, customers, and payments. Drivers should only see their own trips. Add `owner?` checks that verify `record.created_by_id == user.id` or `record.sales_rep_id == user.id`.

3. **Policy scopes** — Ensure every policy has a `Scope` class that filters records appropriately by role:
   ```ruby
   class SalesOrderPolicy < ApplicationPolicy
     class Scope < Scope
       def resolve
         if owner_or_admin?
           scope.where(organization_id: organization.id)
         elsif manager?
           scope.where(organization_id: organization.id, branch_id: user_branch_ids)
         elsif sales_rep?
           scope.where(organization_id: organization.id, created_by_id: user.id)
         elsif driver?
           scope.joins(:delivery_trip).where(delivery_trips: { driver_id: user.id })
         else
           scope.none
         end
       end
     end
   end
   ```

### 7.2 Complete State Machine Definitions

#### SalesOrder States & Transitions

```
States: draft, submitted, on_hold, approved, rejected, dispatched, delivered, partial_delivery, cancelled

Transitions:
┌───────┐    submit!     ┌───────────┐
│ draft │───────────────▶│ submitted │
└───────┘                └─────┬─────┘
                               │
                    ┌──────────┼──────────┐
                    ▼          ▼          ▼
              ┌─────────┐ ┌────────┐ ┌──────────┐
              │ on_hold │ │approved│ │ rejected │
              └────┬────┘ └────┬───┘ └──────────┘
                   │           │
                   │  approve! │
                   └───────────┤
                               ▼
                        ┌────────────┐
                        │ dispatched │
                        └──────┬─────┘
                               │
                    ┌──────────┼──────────┐
                    ▼          ▼          ▼
              ┌───────────┐ ┌─────────┐  (cancelled possible from
              │ delivered │ │partial_ │   draft/submitted/on_hold/approved)
              └───────────┘ │delivery │
                            └─────────┘

Guards:
  submit!     → lines.count > 0
  approve!    → role: manager+
  hold!       → role: manager+, reason required
  reject!     → role: manager+, reason required
  dispatch!   → delivery_trip present & dispatched
  deliver!    → all stops resolved
  cancel!     → not dispatched/delivered/partial
```

#### DeliveryTrip States & Transitions

```
States: draft, planned, dispatched, completed, cancelled

┌───────┐   plan!   ┌─────────┐  dispatch!  ┌────────────┐  (auto)  ┌───────────┐
│ draft │──────────▶│ planned │────────────▶│ dispatched │────────▶│ completed │
└───────┘           └─────────┘             └────────────┘         └───────────┘
    │                    │
    └────── cancel! ─────┘ (only from draft/planned)
                    ▼
              ┌───────────┐
              │ cancelled │
              └───────────┘

Guards:
  plan!      → stops.count > 0, driver assigned
  dispatch!  → vehicle assigned, all orders approved
  complete!  → auto when all stops resolved
  cancel!    → only draft/planned
```

#### TripStop States & Transitions

```
States: pending, delivered, partial_delivery, failed, skipped

┌─────────┐
│ pending │──┬── deliver!  ──────▶ delivered
└─────────┘  ├── partial_deliver! ▶ partial_delivery
             ├── fail!     ──────▶ failed
             └── skip!     ──────▶ skipped

Guards:
  deliver!          → POD present (photo/signature/OTP) OR override with reason
  partial_deliver!  → POD present, per-line qty specified, at least 1 line partially delivered
  fail!             → exception_code required
  skip!             → reason required
```

#### Payment States & Transitions

```
States: draft, confirmed, reversed

┌───────┐  confirm!  ┌───────────┐  reverse!  ┌──────────┐
│ draft │───────────▶│ confirmed │───────────▶│ reversed │
└───────┘            └───────────┘            └──────────┘

Guards:
  confirm!  → amount > 0, customer exists, mode valid
  reverse!  → role: manager+, reason required, creates audit log
```

#### SalesInvoice States & Transitions

```
States: draft, issued, partially_paid, paid, void

┌───────┐  issue!  ┌────────┐     ┌────────────────┐     ┌──────┐
│ draft │────────▶│ issued │────▶│ partially_paid │────▶│ paid │
└───────┘         └────┬───┘     └────────────────┘     └──────┘
                       │                                    
                       └── void! ──▶ ┌──────┐              
                                     │ void │              
                                     └──────┘              

Guards:
  issue!           → lines present, amounts calculated
  void!            → role: manager+, reason required, not partially/fully paid
  partially_paid   → auto when payment allocated (outstanding > 0)
  paid             → auto when outstanding == 0
```

#### ReturnRequest States & Transitions

```
States: draft, submitted, qc_in_progress, qc_completed, credit_note_issued, cancelled

┌───────┐ submit! ┌───────────┐ start_qc! ┌────────────────┐ complete_qc! ┌──────────────┐
│ draft │────────▶│ submitted │──────────▶│ qc_in_progress │────────────▶│ qc_completed │
└───────┘         └───────────┘           └────────────────┘             └──────┬───────┘
                                                                                │
                                                                    issue_cn!   │
                                                                                ▼
                                                                   ┌────────────────────┐
                                                                   │ credit_note_issued │
                                                                   └────────────────────┘

Guards:
  submit!      → lines.count > 0
  start_qc!    → role: warehouse+
  complete_qc! → all lines have QC items
  cancel!      → only from draft/submitted
```

#### StockTransfer States & Transitions

```
States: draft, dispatched, partially_received, received, cancelled

┌───────┐ dispatch! ┌────────────┐ receive! ┌────────────────────┐
│ draft │──────────▶│ dispatched │────────▶│ partially_received │──▶ received
└───────┘           └────────────┘         └────────────────────┘
    │
    └── cancel! ──▶ cancelled

Guards:
  dispatch!  → lines present, source has stock
  receive!   → mark qty per line, damaged qty
  cancel!    → only from draft
```

#### CreditNote States & Transitions

```
States: draft, issued, void

┌───────┐  issue!  ┌────────┐
│ draft │────────▶│ issued │
└───────┘         └────┬───┘
                       │
                       └── void! ──▶ void (only if unapplied_amount == total)
```

#### CollectionSchedule States & Transitions (NEW)

```
States: planned, completed, partial, skipped, rescheduled

┌─────────┐
│ planned │──┬── complete!    ──▶ completed
└─────────┘  ├── partial!     ──▶ partial
             ├── skip!        ──▶ skipped
             └── reschedule!  ──▶ rescheduled (creates new schedule for new date)

Guards:
  complete!    → payment_id required (link to payment record)
  partial!     → payment_id required, collected < expected
  skip!        → reason required
  reschedule!  → new_date required (must be future)
```

### 7.3 Role Permission Quick Reference

```
Legend:  C=Create  R=Read  U=Update  D=Delete  X=Execute(actions)
         ·=No access  b=Branch-scoped  o=Own-records-only

                    Owner  Admin  Manager  SalesRep  Accountant  Warehouse  Driver
Customers           CRUD   CRUD   CRUDb    CRo       R           ·          Ro
Orders              CRUD   CRUD   CRUDb    CRo       R           R          Ro
  approve/hold      X      X      Xb       ·         ·           ·          ·
  cancel            X      X      Xb       Xo(draft) ·           ·          ·
Payments            CRUD   CRUD   CRUDb    Co        CRUD        ·          Co
  confirm           X      X      Xb       ·         X           ·          ·
  reverse           X      X      ·        ·         ·           ·          ·
Invoices            CRUD   CRUD   CRUDb    Ro        CRUD        ·          ·
  issue/void        X      X      Xb       ·         X           ·          ·
CreditNotes         CRUD   CRUD   CRUDb    R         CRUD        ·          ·
Inventory           CRUD   CRUD   CRUDb    ·         ·           CRUDb      ·
StockTransfers      CRUD   CRUD   CRUDb    ·         ·           CRUDb      ·
DeliveryTrips       CRUD   CRUD   CRUDb    Ro        ·           Xb(disp)   RXo
  dispatch          X      X      Xb       ·         ·           Xb         ·
  complete stop     ·      ·      ·        ·         ·           ·          Xo
Products            CRUD   CRUD   CRUDb    R         ·           R          ·
PriceLists          CRUD   CRUD   CRUDb    R         ·           ·          ·
Suppliers           CRUD   CRUD   CRUDb    ·         R           ·          ·
PurchaseInvoices    CRUD   CRUD   CRUDb    ·         R           CRb        ·
Returns             CRUD   CRUD   CRUDb    CRo       R           CRUDb(QC)  CRo
CreditAccounts      CRUD   CRUD   CRUDb    Ro        R           ·          ·
CreditPolicy        RU     RU     R        ·         R           ·          ·
Settings            CRUD   CRUD   RUb      ·         ·           ·          ·
Reports             R(all) R(all) Rb       Ro        R(fin)      R(inv)     ·
Notifications       RXo    RXo    RXo      RXo       RXo         RXo        RXo
CollectionSchedules CRUD   CRUD   CRUDb    RXo       CRUDb       ·          ·
PickLists           R      R      Rb       ·         ·           CRUXb      ·
AuditLogs           R      R      Rb       ·         ·           ·          ·
Users/Invitations   CRUD   CRUD   CRb      ·         ·           ·          ·
Webhooks            CRUD   CRUD   ·        ·         ·           ·          ·
```
