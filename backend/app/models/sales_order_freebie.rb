class SalesOrderFreebie < ApplicationRecord
  belongs_to :sales_order
  belongs_to :scheme
  belongs_to :product

  validates :qty_free, numericality: { greater_than: 0 }
end
