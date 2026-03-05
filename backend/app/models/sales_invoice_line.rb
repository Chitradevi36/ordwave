class SalesInvoiceLine < ApplicationRecord
  # ── Associations ─────────────────────────────────────────────────────────
  belongs_to :sales_invoice, inverse_of: :lines
  belongs_to :product

  # Optional linkage back to order line / stop (for audit / dedup)
  belongs_to :source_sales_order_line, class_name: 'SalesOrderLine', optional: true,
             foreign_key: :source_sales_order_line_id
  belongs_to :source_trip_stop, class_name: 'TripStop', optional: true,
             foreign_key: :source_trip_stop_id

  # ── Validations ──────────────────────────────────────────────────────────
  validates :qty,           numericality: { greater_than: 0 }
  validates :unit_price,    numericality: { greater_than_or_equal_to: 0 }
  validates :discount_pct,  numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :gst_rate,      numericality: { greater_than_or_equal_to: 0 }
  validates :taxable_value, numericality: { greater_than_or_equal_to: 0 }
  validates :tax_amount,    numericality: { greater_than_or_equal_to: 0 }
  validates :line_total,    numericality: { greater_than_or_equal_to: 0 }

  # NOTE: totals are computed by the service before save — NOT in a before_save callback.
  # This preserves the frozen snapshot semantics: once saved, lines are never recomputed
  # from masters.
end
