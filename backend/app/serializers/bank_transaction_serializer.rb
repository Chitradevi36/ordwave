# frozen_string_literal: true

class BankTransactionSerializer < ActiveModel::Serializer
  attributes :id, :bank_account_id, :bank_statement_import_id, :txn_date,
             :value_date, :amount, :direction, :narration, :utr_number,
             :reference_number, :status, :match_score, :match_rule,
             :matched_customer_id, :matched_invoice_id, :matched_payment_id,
             :reviewed_by_id, :processed_at, :match_meta, :created_at, :updated_at

  has_many :candidates, serializer: BankTransactionMatchSerializer

  attribute :matched_customer_name do
    object.matched_customer&.name
  end

  attribute :matched_invoice_number do
    object.matched_invoice&.invoice_number
  end
end
