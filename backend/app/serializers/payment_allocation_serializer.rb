# frozen_string_literal: true

class PaymentAllocationSerializer < BaseSerializer
  def serialize
    {
      id: object.id,
      status: object.status,
      allocated_amount: object.allocated_amount,
      created_at: object.created_at,
      sales_invoice: { id: object.sales_invoice_id, invoice_number: object.sales_invoice&.invoice_number }
    }
  end
end
