# frozen_string_literal: true

class BankStatementImportSerializer < ActiveModel::Serializer
  attributes :id, :organization_id, :bank_account_id, :source_type, :status,
             :file_name, :uploaded_by_id,
             :total_rows, :new_rows, :duplicate_rows,
             :failed_rows, :error_message,
             :created_at, :updated_at

  belongs_to :bank_account, serializer: BankAccountSerializer

  # Map schema column names to UI-friendly aliases
  def total_rows    = object.rows_count
  def new_rows      = object.new_rows_count
  def duplicate_rows = object.duplicate_rows_count
  def failed_rows   = object.failed_rows_count
end
