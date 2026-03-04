class CustomerAddress < ApplicationRecord
  LABELS = %w[billing shipping other].freeze

  belongs_to :customer

  validates :label,  inclusion: { in: LABELS }
  validates :customer, presence: true
end
