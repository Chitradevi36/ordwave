# frozen_string_literal: true

class PaymentSerializer < ActiveModel::Serializer
  attributes :id, :payment_number, :amount, :payment_mode, :status,
             :reference_number, :received_date, :confirmed_at, :reversed_at,
             :reversal_reason, :notes, :created_at, :updated_at,
             :external_payment_id, :external_payment_status, :external_confirmed_at,
             :failed_reason, :retry_count, :retry_status, :next_retry_at,
             :last_retry_at

  belongs_to :organization, serializer: :inline
  belongs_to :branch, serializer: :inline
  belongs_to :customer, serializer: :inline
  belongs_to :created_by, serializer: :inline

  has_many :allocations, serializer: PaymentAllocationSerializer

  attribute :allocated_amount do
    object.allocations.sum(&:allocated_amount)
  end

  attribute :unallocated_amount do
    object.amount - (object.allocations.sum(&:allocated_amount) || 0)
  end
end
