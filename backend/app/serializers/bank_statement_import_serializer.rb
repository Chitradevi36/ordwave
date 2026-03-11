# frozen_string_literal: true

class BankStatementImportSerializer < ActiveModel::Serializer
  attributes :id, :organization_id, :bank_account_id, :source_type, :status,
             :original_filename, :total_rows, :new_rows, :duplicate_rows,
             :failed_rows, :error_message, :imported_by_id,
             :created_at, :updated_at

  belongs_to :bank_account, serializer: BankAccountSerializer
end
