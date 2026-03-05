class InventoryReservation < ApplicationRecord
  STATUSES = %w[active released consumed].freeze

  # ── Associations ─────────────────────────────────────────────────────────────
  belongs_to :organization
  belongs_to :branch
  belongs_to :product
  belongs_to :sales_order

  # ── Validations ──────────────────────────────────────────────────────────────
  validates :qty_reserved, numericality: { greater_than: 0 }
  validates :status,       inclusion: { in: STATUSES }

  # ── Scopes ───────────────────────────────────────────────────────────────────
  scope :active,   ->           { where(status: 'active') }
  scope :for_org,  ->(org)      { where(organization: org) }
  scope :for_branch,  ->(b)     { where(branch: b) }
  scope :for_product, ->(prod)  { where(product: prod) }
  scope :for_order,   ->(order) { where(sales_order: order) }

  # ── Helpers ───────────────────────────────────────────────────────────────────
  def release!
    update!(status: 'released')
  end

  def consume!
    update!(status: 'consumed')
  end
end
