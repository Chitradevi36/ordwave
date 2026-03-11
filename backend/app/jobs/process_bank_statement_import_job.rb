# frozen_string_literal: true

class ProcessBankStatementImportJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 100

  def perform(import_id)
    import = BankStatementImport.find(import_id)
    return if import.completed? || import.failed?

    import.start_processing!

    # Set Current context (no user in background — use a system sentinel)
    Current.organization = import.organization

    file_path = ActiveStorage::Blob.service.path_for(import.file.blob.key)
    result    = BankReconciliation::CsvImportService.call(
      import:   import,
      file_path: file_path
    )

    unless result.success?
      import.mark_failed!(message: result.errors.join("; "))
      return
    end

    import.mark_completed!(
      new_rows:   result.summary[:new_rows],
      duplicates: result.summary[:duplicates],
      failed:     result.summary[:failed_rows],
      total:      result.summary[:total_rows]
    )

    # Run matcher on each new unmatched transaction in batches
    BankTransaction
      .where(bank_statement_import: import, status: :unmatched)
      .find_in_batches(batch_size: BATCH_SIZE) do |batch|
        batch.each do |txn|
          BankReconciliation::Matcher.call(txn, import.organization)
        rescue StandardError => e
          Rails.logger.error("[ProcessBankStatementImportJob] Matcher failed txn #{txn.id}: #{e.message}")
        end
      end

    # Auto-post any transactions that scored >= 95
    auto_post_matched(import)
  rescue StandardError => e
    import&.mark_failed!(message: e.message)
    raise
  end

  private

  def auto_post_matched(import)
    BankTransaction
      .where(bank_statement_import: import, status: :auto_matched)
      .find_in_batches(batch_size: BATCH_SIZE) do |batch|
        batch.each do |txn|
          best = txn.candidates.selected.first
          next unless best&.sales_invoice_id

          result = BankReconciliation::PostingService.call(
            bank_transaction: txn,
            allocations:      [{ invoice_id: best.sales_invoice_id, amount: txn.amount }],
            reviewed_by:      SystemUser.instance   # sentinel user for automated posts
          )

          unless result.success?
            Rails.logger.warn("[ProcessBankStatementImportJob] Auto-post failed txn #{txn.id}: #{result.errors.join(', ')}")
            txn.update!(status: :suggested)          # fall back to human review
          end
        rescue StandardError => e
          Rails.logger.error("[ProcessBankStatementImportJob] Auto-post error txn #{txn.id}: #{e.message}")
          txn.update!(status: :suggested)
        end
      end
  end
end
