# Financial Year Domain — Design Note
**Version**: 1.0  
**Date**: March 11, 2026

---

## 1. Why a Financial Year Model

Without a canonical `FinancialYear` record:
- Return periods are created ad-hoc with free-form date ranges → month boundary bugs
- No year-level locking → invoices can be edited for closed years
- Reports spanning April–March require manual date gymnastics
- Audit trail for "this invoice belongs to FY2025-26" is absent
- Year-close checklist (are all GST returns filed? all payments reconciled?) is impossible to build

The `FinancialYear` model becomes the single authoritative record for all fiscal period operations.

---

## 2. India Fiscal Year Rules

- FY runs **1 April → 31 March**
- Label convention: **FY2025-26** (April 2025 → March 2026)
- GST month 1 of FY = April (month 4 of calendar year)
- Quarterly groupings: Q1 (Apr–Jun), Q2 (Jul–Sep), Q3 (Oct–Dec), Q4 (Jan–Mar)
- GSTR-1 due dates: 11th of next month (monthly filers)
- GSTR-3B due dates: 20th of next month
- Annual return GSTR-9: December 31 of following FY

---

## 3. Model Fields

```ruby
# financial_years
organization_id        bigint   NOT NULL
code                   string   NOT NULL  # "FY2025-26"
label                  string   NOT NULL  # "2025-26"
start_date             date     NOT NULL  # 2025-04-01
end_date               date     NOT NULL  # 2026-03-31
starts_on_month        integer  DEFAULT 4  # extensible for non-India
starts_on_day          integer  DEFAULT 1
status                 string   DEFAULT 'open'  # open/locked/closed/archived
books_locked_at        datetime NULL
gst_locked_at          datetime NULL
closed_at              datetime NULL
closed_by_id           bigint   NULL  → users
notes                  text     NULL
metadata               jsonb    DEFAULT {}
# UNIQUE INDEX on (organization_id, code)
# INDEX on (organization_id, status)
```

---

## 4. Status Lifecycle

```
open ──────────────────────────► locked
  │                                 │
  │  (all returns filed,            │  (year close review done)
  │   usually after Mar 31)         ▼
  └────────────────────────────► closed
                                    │
                                    ▼
                                 archived   (after GSTR-9 filed)
```

Transitions:
- `open → locked`: triggered by `lock_gst!` (restricts new GST return generation for prior periods) or `lock_books!` (restricts invoice editing for the year)
- `locked → closed`: triggered by `close_year!` (full year-close; no further changes allowed)
- `closed → archived`: triggered after all annual filings complete

---

## 5. Helper Methods

```ruby
class FinancialYear < ApplicationRecord
  def includes_date?(date)
    date >= start_date && date <= end_date
  end

  def fiscal_month_for(date)
    # Returns 1-12 where 1=April, 12=March
    offset = (date.month - starts_on_month) % 12
    offset + 1
  end

  def fiscal_quarter_for(date)
    ((fiscal_month_for(date) - 1) / 3) + 1
  end

  def period_start_for_month(calendar_month, calendar_year)
    Date.new(calendar_year, calendar_month, 1)
  end

  def period_end_for_month(calendar_month, calendar_year)
    Date.new(calendar_year, calendar_month, 1).end_of_month
  end

  def calendar_months
    # Returns array of [month, year] tuples for all 12 months of FY
    (0..11).map do |i|
      d = start_date >> i
      [d.month, d.year]
    end
  end

  def previous_financial_year
    self.class.find_by(
      organization_id: organization_id,
      start_date: start_date - 1.year
    )
  end

  def next_financial_year
    self.class.find_by(
      organization_id: organization_id,
      start_date: start_date + 1.year
    )
  end

  def lock_books!(by_user: nil)
    update!(books_locked_at: Time.current, status: 'locked')
    AuditLog.create!(organization_id: organization_id, actor: by_user,
                     auditable: self, action: 'lock_books')
  end

  def lock_gst!(by_user: nil)
    update!(gst_locked_at: Time.current)
    AuditLog.create!(organization_id: organization_id, actor: by_user,
                     auditable: self, action: 'lock_gst')
  end

  def close_year!(by_user: nil)
    update!(closed_at: Time.current, closed_by: by_user, status: 'closed')
    AuditLog.create!(organization_id: organization_id, actor: by_user,
                     auditable: self, action: 'close_year')
  end

  def gst_locked?; gst_locked_at.present?; end
  def books_locked?; books_locked_at.present?; end
  def closed?; status.in?(%w[closed archived]); end
  def open?; status == 'open'; end
end
```

---

## 6. FinancialYear Resolver Service

```ruby
# Gst::FinancialYears::Resolver
#
# Resolves or creates a FinancialYear for a given date + organization.
#
# Usage:
#   fy = Gst::FinancialYears::Resolver.call(organization: org, date: Date.current)
#
class Gst::FinancialYears::Resolver
  def self.call(organization:, date: Date.current, create_if_missing: true)
    # April 1 → March 31 calendar
    fy_start_year = date.month >= 4 ? date.year : date.year - 1
    start_date = Date.new(fy_start_year, 4, 1)
    end_date   = Date.new(fy_start_year + 1, 3, 31)
    code       = "FY#{fy_start_year}-#{(fy_start_year + 1).to_s.last(2)}"

    fy = FinancialYear.find_by(organization: organization, code: code)
    return fy if fy.present?

    return nil unless create_if_missing

    FinancialYear.create!(
      organization: organization,
      code:         code,
      label:        "#{fy_start_year}-#{(fy_start_year + 1).to_s.last(2)}",
      start_date:   start_date,
      end_date:     end_date,
      status:       'open'
    )
  end
end
```

---

## 7. Year-Close Checklist

When triggering `close_year!`, a pre-flight checklist check returns:

```json
{
  "ready_to_close": false,
  "checklist": [
    { "item": "all_gstr1_periods_filed", "status": "fail", "count": 2 },
    { "item": "all_gstr3b_periods_filed", "status": "fail", "count": 2 },
    { "item": "unresolved_reconciliation_issues", "status": "fail", "count": 5 },
    { "item": "all_periods_generated", "status": "pass", "count": 0 },
    { "item": "pending_amendments", "status": "pass", "count": 0 }
  ]
}
```

---

## 8. Financial Year Scopes

```ruby
scope :current,     -> { where('start_date <= ? AND end_date >= ?', Date.current, Date.current) }
scope :open,        -> { where(status: 'open') }
scope :closed,      -> { where(status: %w[closed archived]) }
scope :for_date,    ->(d) { where('start_date <= ? AND end_date >= ?', d, d) }
scope :for_org,     ->(org) { where(organization: org) }
scope :recent,      -> { order(start_date: :desc) }
```

---

## 9. Integration Points

| System | Integration |
|---|---|
| `SalesInvoice` | `invoice_date` is looked up against FY on create; FY stored on `financial_year_id` (cached) |
| `GstReturnPeriod` | Must link to `financial_year_id` |
| `Gst2bImport` | Must link to `financial_year_id` |
| `PurchaseInvoice` | `invoice_date` checked against FY lock |
| `Report / InsightsController` | FY filter becomes primary scope |

---

## 10. API Endpoints

```
GET  /api/v1/financial_years            → list all FYs for org
GET  /api/v1/financial_years/current    → resolve current FY
GET  /api/v1/financial_years/:id        → show FY details + checklist
POST /api/v1/financial_years/:id/lock_gst   → admin/CA only
POST /api/v1/financial_years/:id/lock_books → admin/owner only
POST /api/v1/financial_years/:id/close      → admin/owner only
```
