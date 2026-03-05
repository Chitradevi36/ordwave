class StockTransferLine < ApplicationRecord
  belongs_to :stock_transfer, inverse_of: :lines
  belongs_to :product

  validates :qty_requested,  numericality: { greater_than: 0 }
  validates :qty_dispatched, numericality: { greater_than_or_equal_to: 0 }
  validates :qty_received,   numericality: { greater_than_or_equal_to: 0 }
  validates :qty_damaged,    numericality: { greater_than_or_equal_to: 0 }

  validate :dispatched_within_requested
  validate :received_within_dispatched

  # remaining qty still in transit (dispatched but not yet accounted for)
  def qty_in_transit
    qty_dispatched - qty_received - qty_damaged
  end

  def fully_accounted?
    qty_dispatched > 0 && qty_in_transit <= 0
  end

  private

  def dispatched_within_requested
    return if qty_dispatched.to_d <= qty_requested.to_d
    errors.add(:qty_dispatched, "cannot exceed qty requested (#{qty_requested})")
  end

  def received_within_dispatched
    return if (qty_received.to_d + qty_damaged.to_d) <= qty_dispatched.to_d
    errors.add(:qty_received, "qty_received + qty_damaged cannot exceed qty dispatched (#{qty_dispatched})")
  end
end
