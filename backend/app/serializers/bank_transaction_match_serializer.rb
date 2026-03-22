# frozen_string_literal: true

class BankTransactionMatchSerializer < BaseSerializer
  def serialize
    {
      id: object.id,
      bank_transaction_id: object.bank_transaction_id,
      customer_id: object.customer_id,
      sales_invoice_id: object.sales_invoice_id,
      score: object.score,
      rule_code: object.rule_code,
      explanation: object.explanation,
      selected: object.selected,
      created_at: object.created_at,
      customer_name: object.customer&.name,
      invoice_number: object.sales_invoice&.invoice_number,
      invoice_amount: object.sales_invoice&.grand_total,
      invoice_outstanding: object.sales_invoice&.outstanding_amount
    }
  end
end
