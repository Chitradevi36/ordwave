class RetailerPriceListAssignment < ApplicationRecord
  belongs_to :customer    # retailer
  belongs_to :price_list

  validates :customer_id,   presence: true
  validates :price_list_id, presence: true
  validates :price_list_id, uniqueness: {
    scope: :customer_id,
    message: 'already assigned to this retailer'
  }
  validate  :ends_on_after_starts_on, if: -> { starts_on.present? && ends_on.present? }
  validate  :list_type_must_be_retailer_specific

  scope :active_on,  lambda { |date = Date.current|
    where(active: true)
      .where('starts_on IS NULL OR starts_on <= ?', date)
      .where('ends_on IS NULL OR ends_on >= ?', date)
  }

  private

  def ends_on_after_starts_on
    errors.add(:ends_on, 'must be after starts on') if ends_on < starts_on
  end

  def list_type_must_be_retailer_specific
    return unless price_list
    unless price_list.list_type.in?(%w[retailer_specific promo])
      errors.add(:price_list, "must be of type 'retailer_specific' or 'promo'")
    end
  end
end
