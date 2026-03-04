class PriceList < ApplicationRecord
  LIST_TYPES = %w[standard promo retailer_specific tier_specific].freeze
  STATUSES   = %w[active inactive].freeze

  # ── Associations ────────────────────────────────────────────────────────────
  belongs_to :organization
  belongs_to :branch, optional: true   # nil = org-wide; present = branch-scoped

  has_many :items,
           class_name: 'PriceListItem',
           dependent:  :destroy,
           inverse_of: :price_list

  has_many :retailer_assignments,
           class_name: 'RetailerPriceListAssignment',
           dependent:  :destroy

  has_many :tier_assignments,
           class_name: 'TierPriceListAssignment',
           dependent:  :destroy

  # ── Validations ─────────────────────────────────────────────────────────────
  validates :name,      presence: true, length: { maximum: 150 }
  validates :list_type, inclusion: { in: LIST_TYPES }
  validates :status,    inclusion: { in: STATUSES }
  validate  :valid_to_after_valid_from, if: -> { valid_from.present? && valid_to.present? }
  validate  :only_one_active_standard_per_branch, if: -> { list_type == 'standard' && active? }

  # ── Scopes ──────────────────────────────────────────────────────────────────
  scope :not_deleted,    -> { where(deleted_at: nil) }
  scope :active_lists,   -> { not_deleted.where(status: 'active') }
  scope :by_type,        ->(t)  { where(list_type: t) }
  scope :for_branch,     ->(bid) { where(branch_id: bid) }
  scope :for_org,        ->(oid) { where(organization_id: oid) }
  scope :standard,       -> { where(list_type: 'standard') }
  scope :current_promo,  lambda { |date = Date.current|
    where(list_type: 'promo')
      .where('valid_from IS NULL OR valid_from <= ?', date)
      .where('valid_to IS NULL OR valid_to >= ?', date)
  }
  scope :date_valid, lambda { |date = Date.current|
    where('valid_from IS NULL OR valid_from <= ?', date)
      .where('valid_to IS NULL OR valid_to >= ?', date)
  }

  # ── Instance helpers ────────────────────────────────────────────────────────
  def active?
    status == 'active' && deleted_at.nil?
  end

  def expired?
    valid_to.present? && valid_to < Date.current
  end

  def soft_delete!
    update!(deleted_at: Time.current, status: 'inactive')
  end

  def deleted?
    deleted_at.present?
  end

  def item_count
    items.count
  end

  private

  def valid_to_after_valid_from
    errors.add(:valid_to, 'must be after valid from') if valid_to <= valid_from
  end

  def only_one_active_standard_per_branch
    return unless branch_id.present?

    conflict = PriceList.not_deleted
                        .where(branch_id: branch_id, list_type: 'standard', status: 'active')
                        .where.not(id: id)

    errors.add(:base, 'A branch can only have one active standard price list') if conflict.exists?
  end
end
