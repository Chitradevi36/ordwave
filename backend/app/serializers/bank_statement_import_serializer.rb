# frozen_string_literal: true

class BankStatementImportSerializer < BaseSerializer
  def serialize
    {
      id: object.id,
      organization_id: object.organization_id,
      bank_account_id: object.bank_account_id,
      source_type: object.source_type,
      status: object.status,
      file_name: object.file_name,
      uploaded_by_id: object.uploaded_by_id,
      total_rows: object.rows_count,
      new_rows: object.new_rows_count,
      duplicate_rows: object.duplicate_rows_count,
      failed_rows: object.failed_rows_count,
      error_message: object.error_message,
      created_at: object.created_at,
      updated_at: object.updated_at,
      bank_account: BankAccountSerializer.new(object.bank_account).serialize
    }
  end
end
