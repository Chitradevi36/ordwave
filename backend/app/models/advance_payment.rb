class AdvancePayment < ApplicationRecord
  STATUSES = %w[unapplied partially_applied applied refunded].freeze

  belongs_to :organization
  belongs_to :branch
  belongs_to :customer
  belongs_to :source_payment, class_name: 'Payment'

  has_many :audit_logs, as: :auditable, dependent: :nullify

  validates :original_amount, numericality: { greater_than: 0 }
  validates :balance,         numericality: { greater_than_or_equal_to: 0 }
  validates :status,          inclusion: { in: STATUSES }

  scope :for_org,      ->(org) { where(organization: org) }
  scope :for_customer, ->(c)   { where(customer: c) }
  scope :unapplied,    ->      { where(status: %w[unapplied partially_applied]) }
  scope :recent,       ->      { order(created_at: :desc) }

  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }

  def applicable? = unapplied? || partially_applied?
  def refundable? = unapplied? || partially_applied?

  # Recompute status from balance
  def sync_status!
    new_status = if balance.zero?
                   'applied'
                 elsif balance < original_amount
                   'partially_applied'
                 else
                   'unapplied'
                 end
    update_column(:status, new_status) unless status == new_status
  end
end
