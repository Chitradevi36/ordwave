class PaymentAllocation < ApplicationRecord
  STATUSES = %w[active reversed].freeze

  belongs_to :payment
  belongs_to :sales_invoice

  validates :allocated_amount, numericality: { greater_than: 0 }
  validates :status, inclusion: { in: STATUSES }

  validate :amount_does_not_exceed_invoice_outstanding, on: :create

  scope :active,    -> { where(status: 'active') }
  scope :reversed,  -> { where(status: 'reversed') }

  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }

  private

  def amount_does_not_exceed_invoice_outstanding
    return unless sales_invoice && allocated_amount

    if allocated_amount > sales_invoice.outstanding_amount
      errors.add(:allocated_amount,
        "#{allocated_amount} exceeds invoice outstanding #{sales_invoice.outstanding_amount}")
    end
  end
end
