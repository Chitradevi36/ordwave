class TierPriceListAssignment < ApplicationRecord
  TIERS = Customer::TIERS

  belongs_to :branch
  belongs_to :price_list

  validates :branch_id,     presence: true
  validates :retailer_tier, presence: true, inclusion: { in: TIERS }
  validates :price_list_id, presence: true
  validates :retailer_tier, uniqueness: {
    scope: [:branch_id, :price_list_id],
    message: 'already has an assignment for this tier and price list'
  }
  validate  :ends_on_after_starts_on, if: -> { starts_on.present? && ends_on.present? }
  validate  :list_type_must_be_tier_specific

  scope :active_on, lambda { |date = Date.current|
    where(active: true)
      .where('starts_on IS NULL OR starts_on <= ?', date)
      .where('ends_on IS NULL OR ends_on >= ?', date)
  }
  scope :for_tier, ->(tier) { where(retailer_tier: tier) }

  private

  def ends_on_after_starts_on
    errors.add(:ends_on, 'must be after starts on') if ends_on < starts_on
  end

  def list_type_must_be_tier_specific
    return unless price_list
    unless price_list.list_type == 'tier_specific'
      errors.add(:price_list, "must be of type 'tier_specific'")
    end
  end
end
