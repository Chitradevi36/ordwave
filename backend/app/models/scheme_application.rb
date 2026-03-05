class SchemeApplication < ApplicationRecord
  SOURCES = %w[preview submit_snapshot].freeze

  belongs_to :organization
  belongs_to :sales_order, optional: true
  belongs_to :scheme
  belongs_to :applied_by, class_name: 'User', optional: true

  validates :source, inclusion: { in: SOURCES }

  scope :for_order,   ->(oid)   { where(sales_order_id: oid) }
  scope :snapshots,   ->        { where(source: 'submit_snapshot') }
end
