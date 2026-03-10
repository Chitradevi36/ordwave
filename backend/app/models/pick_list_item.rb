# == Schema Information
# pick_list_items: id, pick_list_id, product_id, qty_requested, qty_picked,
#                 bin_location, picked_at, created_at, updated_at
class PickListItem < ApplicationRecord
  belongs_to :pick_list
  belongs_to :product

  validates :qty_requested, numericality: { greater_than: 0, only_integer: true }
  validates :qty_picked,    numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :product_id,    uniqueness: { scope: :pick_list_id }

  def fulfilled?; qty_picked >= qty_requested end

  def pick!(qty)
    raise ArgumentError, "qty must be positive" unless qty.to_i > 0
    update!(qty_picked: qty.to_i, picked_at: Time.current)
  end
end
