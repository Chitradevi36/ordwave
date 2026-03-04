class CustomerContact < ApplicationRecord
  belongs_to :customer

  validates :name,     presence: true
  validates :customer, presence: true

  scope :primary, -> { where(is_primary: true) }
end
