# frozen_string_literal: true

class BankTransactionMatchSerializer < ActiveModel::Serializer
  attributes :id, :bank_transaction_id, :customer_id, :sales_invoice_id,
             :score, :rule_code, :explanation, :selected, :created_at

  attribute :customer_name do
    object.customer&.name
  end

  attribute :invoice_number do
    object.sales_invoice&.invoice_number
  end

  attribute :invoice_amount do
    object.sales_invoice&.grand_total
  end

  attribute :invoice_outstanding do
    object.sales_invoice&.outstanding_amount
  end
end
