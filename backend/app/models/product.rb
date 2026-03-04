class Product < ApplicationRecord
  VALID_STATUSES = %w[active discontinued].freeze
  VALID_GST_RATES = [0, 5, 12, 18, 28].freeze
  SKU_FORMAT = /\A[A-Z0-9\-_]+\z/

  # ── Associations ────────────────────────────────────────────────────────────
  belongs_to :organization
  belongs_to :product_category
  belongs_to :units_of_measure, class_name: 'UnitsOfMeasure', foreign_key: :units_of_measure_id
  belongs_to :hsn_sac_code   # must exist in master

  has_many :price_list_items, dependent: :restrict_with_error

  # Convenience: product.hsn_code => product.hsn_sac_code.code
  delegate :code, to: :hsn_sac_code, prefix: :hsn, allow_nil: true

  # ── Callbacks ───────────────────────────────────────────────────────────────
  before_validation :upcase_sku
  before_validation :auto_fill_gst_from_hsn, if: :hsn_sac_code_id_changed?

  # ── Validations ─────────────────────────────────────────────────────────────
  validates :sku,  presence: true,
                   format:   { with: SKU_FORMAT, message: 'only uppercase letters, numbers, hyphens, and underscores' },
                   length:   { maximum: 50 }
  validates :name, presence: true, length: { maximum: 150 }
  validates :product_category, presence: true
  validates :units_of_measure,  presence: true
  validates :hsn_sac_code,     presence: true
  validates :gst_rate, inclusion: { in: VALID_GST_RATES, message: 'must be 0, 5, 12, 18, or 28' }
  validates :status,   inclusion: { in: VALID_STATUSES }
  validates :min_order_qty, numericality: { greater_than: 0 }
  validates :purchase_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :weight_kg,      numericality: { greater_than: 0 },             allow_nil: true

  # SKU uniqueness scoped to org (allow same SKU across orgs; uniqueness on deleted=nil only)
  validates :sku, uniqueness: {
    scope: :organization_id,
    conditions: -> { where(deleted_at: nil) },
    message: 'has already been taken for this organization'
  }

  # Validate SKU immutability after first usage (checked at model level)
  validate :sku_immutable_after_usage, on: :update

  # ── Scopes ──────────────────────────────────────────────────────────────────
  scope :active,      -> { where(status: 'active', deleted_at: nil) }
  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :for_org,     ->(org_id) { where(organization_id: org_id) }
  scope :by_status,   ->(s)      { where(status: s) }
  scope :by_category, ->(cat_id) { where(product_category_id: cat_id) }
  scope :search_sku_name, lambda { |q|
    where("sku ILIKE :q OR name ILIKE :q", q: "%#{q}%")
  }

  # ── Instance methods ────────────────────────────────────────────────────────
  # Expose hsn_code string for convenience / serializers
  def hsn_code = hsn_sac_code&.code

  def soft_delete!
    update!(deleted_at: Time.current, status: 'discontinued')
  end

  def deleted?
    deleted_at.present?
  end

  # Returns true if this product is referenced in any order line / invoice line.
  # Currently we check price_list_items as a proxy; extend when orders exist.
  def used_in_orders?
    # Placeholder — extend with SalesOrderLine.exists?(product: self) when orders module lands.
    false
  end

  def gsplit_rates
    half = gst_rate / 2.0
    { cgst: half, sgst: half, igst: gst_rate }
  end

  private

  def upcase_sku
    self.sku = sku.to_s.strip.upcase
  end

  # Auto-fill gst_rate snapshot from master whenever the HSN reference changes.
  # The stored gst_rate is intentionally a snapshot so historical order lines
  # remain frozen even after the master is updated.
  def auto_fill_gst_from_hsn
    return unless hsn_sac_code
    self.gst_rate = hsn_sac_code.gst_rate
  end

  def sku_immutable_after_usage
    return unless sku_changed? && used_in_orders?

    errors.add(:sku, 'cannot be changed after the product has been used in an order')
  end
end
