class InventoryLevel < ApplicationRecord
  # ── Associations ─────────────────────────────────────────────────────────────
  belongs_to :organization
  belongs_to :branch
  belongs_to :product

  # ── Validations ──────────────────────────────────────────────────────────────
  validates :qty_on_hand,  numericality: { greater_than_or_equal_to: 0 }
  validates :qty_reserved, numericality: { greater_than_or_equal_to: 0 }
  validates :product_id,   uniqueness: { scope: :branch_id, message: 'already has an inventory level for this branch' }

  # ── Scopes ───────────────────────────────────────────────────────────────────
  scope :for_org,     ->(org)    { where(organization: org) }
  scope :for_branch,  ->(branch) { where(branch: branch) }
  scope :for_product, ->(prod)   { where(product: prod) }
  scope :in_stock,    ->         { where('qty_on_hand > 0') }
  scope :low_stock,   ->         { where('min_qty_threshold IS NOT NULL AND qty_on_hand <= min_qty_threshold') }
  scope :search_q,    ->(q) {
    joins(:product).where('products.name ILIKE :q OR products.sku ILIKE :q', q: "%#{sanitize_sql_like(q)}%")
  }
  scope :by_category, ->(cat_id) {
    joins(:product).where(products: { product_category_id: cat_id })
  }

  # ── Class helpers ─────────────────────────────────────────────────────────────
  # Backward-compat: apply a signed on_hand delta. New code should prefer apply_movement_delta.
  def self.apply_delta(organization:, branch:, product:, delta:)
    level = find_or_initialize_by(organization: organization, branch: branch, product: product)
    level.qty_on_hand = (level.qty_on_hand || 0) + delta
    level.save!
    level
  end

  # Apply both on_hand and reserved deltas atomically (used by Inventory::PostMovement).
  def self.apply_movement_delta(organization:, branch:, product:, on_hand_delta: 0, reserved_delta: 0)
    level = find_or_initialize_by(organization: organization, branch: branch, product: product)
    level.qty_on_hand  = (level.qty_on_hand  || 0) + on_hand_delta
    level.qty_reserved = (level.qty_reserved || 0) + reserved_delta
    # Guard: reserved can never go below 0
    level.qty_reserved = 0 if level.qty_reserved < 0
    level.save!
    level
  end

  # ── Instance helpers ──────────────────────────────────────────────────────────
  def qty_available
    [(qty_on_hand - qty_reserved), 0].max
  end

  def low_stock?
    min_qty_threshold.present? && qty_on_hand <= min_qty_threshold
  end
end
