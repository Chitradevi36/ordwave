# frozen_string_literal: true

module BankReconciliation
  # Aggregates import + transaction summary statistics for the
  # Bank Reconciliation dashboard widget.
  #
  # Usage:
  #   BankReconciliation::ImportDashboardQuery.call(
  #     organization:    org,
  #     bank_account_id: nil,
  #     date_from:       30.days.ago.to_date,
  #     date_to:         Date.current
  #   )
  class ImportDashboardQuery
    Result = Struct.new(
      :total_credits_imported,   # count
      :total_amount_imported,    # sum INR
      :auto_matched_count,
      :auto_matched_amount,
      :needs_review_count,
      :needs_review_amount,
      :unmatched_count,
      :unmatched_amount,
      :duplicates_count,
      :confirmed_count,
      :confirmed_amount,
      :ignored_count,
      :recent_imports,           # Array<Hash> last 5 imports
      keyword_init: true
    )

    def self.call(organization:, bank_account_id: nil, date_from: nil, date_to: nil)
      new(
        organization:    organization,
        bank_account_id: bank_account_id,
        date_from:       date_from,
        date_to:         date_to
      ).call
    end

    def initialize(organization:, bank_account_id: nil, date_from: nil, date_to: nil)
      @org            = organization
      @bank_account_id = bank_account_id
      @date_from      = parse_date(date_from) || 30.days.ago.to_date
      @date_to        = parse_date(date_to)   || Date.current
    end

    def call
      txns = base_txn_scope

      by_status = txns.group(:status).sum(:amount).transform_keys(&:to_s)
      counts    = txns.group(:status).count.transform_keys(&:to_s)

      # Duplicate count comes from import rows, not transactions, so we count
      # imports within the period and sum their duplicate_rows_count
      dup_count = import_scope.sum(:duplicate_rows_count)

      Result.new(
        total_credits_imported: txns.count,
        total_amount_imported:  txns.sum(:amount).to_d.round(2),

        auto_matched_count:  counts.fetch("auto_matched", 0),
        auto_matched_amount: by_status.fetch("auto_matched", 0).to_d.round(2),

        needs_review_count:  counts.fetch("suggested", 0),
        needs_review_amount: by_status.fetch("suggested", 0).to_d.round(2),

        unmatched_count:  counts.fetch("unmatched", 0),
        unmatched_amount: by_status.fetch("unmatched", 0).to_d.round(2),

        duplicates_count: dup_count.to_i,

        confirmed_count:  counts.fetch("matched", 0),
        confirmed_amount: by_status.fetch("matched", 0).to_d.round(2),

        ignored_count: counts.fetch("ignored", 0),

        recent_imports: recent_import_summaries
      )
    end

    private

    def base_txn_scope
      scope = BankTransaction
                .for_org(@org)
                .credits
                .where("txn_date BETWEEN ? AND ?", @date_from, @date_to)
      scope = scope.where(bank_account_id: @bank_account_id) if @bank_account_id.present?
      scope
    end

    def import_scope
      scope = BankStatementImport
                .for_org(@org)
                .where("created_at::date BETWEEN ? AND ?", @date_from, @date_to)
      scope = scope.where(bank_account_id: @bank_account_id) if @bank_account_id.present?
      scope
    end

    def recent_import_summaries
      import_scope
        .recent
        .limit(5)
        .map do |imp|
          {
            id:            imp.id,
            file_name:     imp.file_name,
            source_type:   imp.source_type,
            status:        imp.status,
            total:         imp.rows_count,
            new:           imp.new_rows_count,
            duplicates:    imp.duplicate_rows_count,
            failed:        imp.failed_rows_count,
            imported_at:   imp.created_at.iso8601
          }
        end
    end

    def parse_date(val)
      return nil if val.blank?
      val.to_date
    rescue ArgumentError, TypeError
      nil
    end
  end
end
