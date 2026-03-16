# frozen_string_literal: true

class PaymentAllocationSerializer < ActiveModel::Serializer
  attributes :id, :status, :allocated_amount, :created_at

  belongs_to :sales_invoice, serializer: :inline
end
