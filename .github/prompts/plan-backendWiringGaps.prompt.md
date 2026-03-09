# Backend Wiring Gaps — Implementation Plan

## Context

The UI session added 12 feature surfaces (5 modified pages + 7 new pages). The backend services and models are largely in place, but routes and controller actions are missing. This plan closes those gaps in priority order.

---

## Gap 1 — Routes (config/routes.rb)

Add all missing entries in one pass:

```ruby
# Sales Invoices — e-waybill
resources :sales_invoices, only: %i[index show create] do
  member do
    post :issue
    post :void_invoice, path: 'void'
    get  :pdf
    post :einvoice
    post :ewaybill          # ← ADD
    post :cancel_ewaybill   # ← ADD (for future cancellation flow)
  end
  # ...
end

# Credit Notes — apply to invoice
resources :credit_notes, only: %i[index show] do
  member do
    post :void_note, path: 'void'
    post :apply             # ← ADD
  end
  # ...
end

# Delivery — stop rejections
resources :delivery_trips, only: %i[index show create update] do
  # ...
  resources :trip_stops, only: %i[index show] do
    member do
      post :complete
    end
    resources :rejections, only: %i[create],   # ← ADD
              controller: 'stop_rejections'
  end
end

# Supplier Debit Notes — new resource  ← ADD ENTIRE BLOCK
resources :supplier_debit_notes, only: %i[index show create update] do
  member do
    post :issue
    post :void_note, path: 'void'
  end
end

# Analytics — returns + schemes  ← ADD to existing analytics scope
scope :analytics, controller: :analytics do
  get :overview,          action: :overview
  get :sales,             action: :sales
  get :collections,       action: :collections
  get 'collections/export', action: :collections_csv
  get :credit_risk,       action: :credit_risk
  get :beat_performance,  action: :beat_performance
  get :inventory_health,  action: :inventory_health
  get :returns,           action: :returns    # ← ADD
  get :schemes,           action: :schemes    # ← ADD
end

# Compliance / GSTR-1  ← ADD ENTIRE BLOCK
namespace :compliance do
  scope :gstr1, controller: :gstr1 do
    get :preview
    get :export
  end
end
```

---

## Gap 2 — SalesInvoicesController#ewaybill

File: `backend/app/controllers/api/v1/sales_invoices_controller.rb`

```ruby
# POST /api/v1/sales_invoices/:id/ewaybill
def ewaybill
  invoice = find_invoice   # existing private helper
  authorize invoice, :update?

  result = Gst::EwaybillService.generate(
    sales_invoice:    invoice,
    transport_mode:   params[:transport_mode] || 'road',
    vehicle_number:   params[:vehicle_number],
    transporter_id:   params[:transporter_id],
    transporter_name: params[:transporter_name],
    distance_km:      params[:distance_km]
  )

  if result.success?
    render_success(serialize_invoice(invoice.reload))
  else
    render_errors(result.errors)
  end
end
```

The `SalesInvoice` serializer also needs these fields added:
```ruby
attributes :ewaybill_number, :ewaybill_status, :ewaybill_valid_upto, :ewaybill_generated_at
```
These come from the latest active `EwaybillRequest` associated with the invoice.

---

## Gap 3 — CreditNotesController#apply

File: `backend/app/controllers/api/v1/credit_notes_controller.rb`

```ruby
# POST /api/v1/credit_notes/:id/apply
# Body: { applications: [{ sales_invoice_id: 123, amount: 500.00 }] }
def apply
  note = find_credit_note   # existing private helper
  authorize note, :update?

  result = CreditNotes::ApplyService.call(
    credit_note:  note,
    applications: params.require(:applications).map do |a|
      { sales_invoice_id: a[:sales_invoice_id], amount: a[:amount].to_d }
    end,
    applied_by: current_user
  )

  if result.success?
    render_success(serialize_credit_note(note.reload))
  else
    render_errors(result.errors)
  end
end
```

Check whether `CreditNotes::ApplyService` already exists in `backend/app/services/credit_notes/`.
If not, create it:
- Validate total applied ≤ note balance
- Create `CreditNoteApplication` records (or `PaymentAllocation` depending on existing model)
- Update invoice outstanding balance
- Update note `applied_amount` and status → `applied` if fully used

---

## Gap 4 — StopRejectionsController (new)

File: `backend/app/controllers/api/v1/stop_rejections_controller.rb`

```ruby
module Api
  module V1
    class StopRejectionsController < BaseController
      before_action :require_organization!
      before_action :set_trip
      before_action :set_stop

      # POST /api/v1/delivery_trips/:delivery_trip_id/trip_stops/:trip_stop_id/rejections
      def create
        authorize @trip, :update?

        rejection = @stop.rejections.build(rejection_params.merge(
          organization: current_organization,
          recorded_by:  current_user
        ))

        if rejection.save
          handle_auto_return(rejection) if rejection.auto_return?
          render_success(serialize_rejection(rejection), status: :created)
        else
          render_errors(rejection.errors.full_messages)
        end
      end

      private

      def set_trip
        @trip = current_organization.delivery_trips.find(params[:delivery_trip_id])
      end

      def set_stop
        @stop = @trip.trip_stops.find(params[:trip_stop_id])
      end

      def rejection_params
        params.require(:rejection).permit(
          :reason_code, :condition, :qty_rejected, :auto_return, :notes
        )
      end

      def handle_auto_return(rejection)
        # Create return request automatically if auto_return: true
        # Wire to existing ReturnRequests::CreateService or similar
      end
    end
  end
end
```

Check whether a `StopRejection` model/migration exists. If not, a migration is needed:
```ruby
create_table :stop_rejections do |t|
  t.references :trip_stop,     null: false, foreign_key: true
  t.references :organization,  null: false, foreign_key: true
  t.references :recorded_by,   null: false, foreign_key: { to_table: :users }
  t.references :return_request, foreign_key: true   # populated after auto-return
  t.string  :reason_code,   null: false
  t.string  :condition,     null: false, default: 'unopened'
  t.decimal :qty_rejected,  null: false, precision: 10, scale: 3
  t.boolean :auto_return,   null: false, default: true
  t.text    :notes
  t.timestamps
end
add_index :stop_rejections, :reason_code
```

---

## Gap 5 — SupplierDebitNotesController (new)

File: `backend/app/controllers/api/v1/supplier_debit_notes_controller.rb`

Model + service already exist. Only the controller is missing.

Actions needed:
- `index`   — scoped, paginated, filterable by status/supplier
- `show`    — with lines
- `create`  — draft, nested lines
- `update`  — patch draft fields
- `issue`   — `POST /:id/issue`
- `void`    — `POST /:id/void` (body: `{ reason: "..." }`)

Serializer fields (based on UI expectations):
```
id, note_number, note_date, status, reason, void_reason,
subtotal, tax_total, total_amount, currency, notes,
issued_at, voided_at, created_at,
supplier: { id, name, code, gstin },
branch: { id, name },
purchase_invoice: { id, invoice_number, invoice_date },
lines: [{ id, product_name, product_sku, hsn_code, qty,
          unit_price, taxable_value, gst_rate, tax_amount, line_total, reason_code }]
```

---

## Gap 6 — AnalyticsController#returns + #schemes

File: `backend/app/controllers/api/v1/analytics_controller.rb`

```ruby
# GET /api/v1/analytics/returns
def returns
  data = cached("returns") do
    {
      summary:     returns_query.summary,
      by_reason:   returns_query.by_reason,
      by_product:  returns_query.by_product,
      by_customer: returns_query.by_customer,
      by_month:    returns_query.by_month,
    }
  end
  render_success(data)
end

# GET /api/v1/analytics/schemes
def schemes
  data = cached("schemes") do
    {
      summary: schemes_query.summary,
      schemes: schemes_query.per_scheme,
    }
  end
  render_success(data)
end
```

Create query objects:
- `backend/app/queries/analytics/returns_query.rb` — aggregates `return_requests` by reason_code, product, customer, month
- `backend/app/queries/analytics/schemes_query.rb` — aggregates `scheme_redemptions` + budget utilization from `schemes`

---

## Gap 7 — ComplianceController (new, GSTR-1)

File: `backend/app/controllers/api/v1/compliance/gstr1_controller.rb`

The service `Gst::Gstr1ExportService` already exists.

```ruby
module Api
  module V1
    module Compliance
      class Gstr1Controller < BaseController
        before_action :require_organization!
        before_action :set_period

        skip_after_action :verify_authorized
        skip_after_action :verify_policy_scoped

        # GET /api/v1/compliance/gstr1/preview
        def preview
          result = Gst::Gstr1ExportService.call(
            organization: current_organization,
            period_from:  @period_from,
            period_to:    @period_to
          )
          render_success(serialize_gstr1(result))
        end

        # GET /api/v1/compliance/gstr1/export?format=json
        def export
          result = Gst::Gstr1ExportService.call(
            organization: current_organization,
            period_from:  @period_from,
            period_to:    @period_to
          )

          json_payload = Gst::Gstr1JsonBuilder.build(result)
          filename = "GSTR1_#{@year}_#{@month.to_s.rjust(2, '0')}.json"

          send_data json_payload.to_json,
                    type: 'application/json',
                    disposition: "attachment; filename=#{filename}"
        end

        private

        def set_period
          @year  = params.require(:year).to_i
          @month = params.require(:month).to_i
          @period_from = Date.new(@year, @month, 1)
          @period_to   = @period_from.end_of_month
        end

        def serialize_gstr1(result)
          {
            period:  "#{@year}-#{@month.to_s.rjust(2, '0')}",
            summary: {
              total_invoices: result.b2b_invoices.size + result.b2c_large.size + result.b2c_small.size,
              total_taxable:  sum_field(result.b2b_invoices + result.b2c_large + result.b2c_small, :taxable_value),
              # ...
            },
            b2b:         group_b2b(result.b2b_invoices),
            b2c:         group_b2c(result.b2c_large + result.b2c_small),
            cdnr:        group_cdnr(result.credit_debit_notes),
            hsn_summary: result.hsn_summary,
          }
        end
      end
    end
  end
end
```

Check whether `Gst::Gstr1JsonBuilder` exists. If not, create it to produce the official NIC JSON schema.

---

## Implementation Order

1. Routes (single file change, unlocks everything)
2. Gap 2 — `ewaybill` action (service exists, ~15 lines)
3. Gap 3 — `credit_notes#apply` action (check if ApplyService exists first)
4. Gap 5 — `SupplierDebitNotesController` (model + service exist)
5. Gap 7 — `ComplianceController` (service exists)
6. Gap 6 — Analytics returns + schemes (need query objects)
7. Gap 4 — StopRejectionsController + migration (most new model work)

---

## Checklist Before Ship

- [ ] `SalesInvoice` serializer exposes ewaybill fields (via `ewaybill_requests.last` or a dedicated scope)
- [ ] `CreditNotes::ApplyService` exists or is created
- [ ] `StopRejection` migration exists
- [ ] `AnalyticsPolicy` allows `read?` for `returns` and `schemes` actions (or add them to the skip list)
- [ ] GSTR-1 authorization — owner/admin/accountant only
- [ ] Cache keys for `returns` and `schemes` analytics include date range params
- [ ] Existing `schemes` resource routes don't conflict with `analytics/schemes`
