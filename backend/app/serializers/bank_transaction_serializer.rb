# frozen_string_literal: true

class BankTransactionSerializer < BaseSerializer
  def serialize
    {
      id: object.id,
      bank_account_id: object.bank_account_id,
      bank_statement_import_id: object.bank_statement_import_id,
      txn_date: object.txn_date,
      value_date: object.value_date,
      amount: object.amount,
      direction: object.direction,
      narration: object.narration,
      utr_number: object.utr_number,
      reference_number: object.reference_number,
      status: object.status,
      match_score: object.match_score,
      match_rule: object.match_rule,
      matched_customer_id: object.matched_customer_id,
      matched_invoice_id: object.matched_invoice_id,
      matched_payment_id: object.matched_payment_id,
      reviewed_by_id: object.reviewed_by_id,
      processed_at: object.processed_at,
      match_meta: object.match_meta,
      created_at: object.created_at,
      updated_at: object.updated_at,
      matched_customer_name: object.matched_customer&.name,
      matched_invoice_number: object.matched_invoice&.invoice_number,
      candidates: object.candidates.map { |c| BankTransactionMatchSerializer.new(c).serialize }
    }
  end
end
