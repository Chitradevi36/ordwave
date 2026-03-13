# frozen_string_literal: true

module BankReconciliation
  # Orchestrates all matching rules for a single BankTransaction.
  #
  # Scoring thresholds (per spec):
  #   >= 95  → status: auto_matched  (will be auto-posted by background job)
  #   80–94  → status: suggested     (surfaced in review queue)
  #   < 80   → status: unmatched     (Needs Review with no suggestion)
  #
  # Usage:
  #   result = BankReconciliation::Matcher.call(txn)
  #   result.status          # => "auto_matched" | "suggested" | "unmatched"
  #   result.best_candidate  # => BankTransactionMatch or nil
  class Matcher
    AUTO_POST_THRESHOLD = 95.0
    SUGGEST_THRESHOLD   =  80.0

    Result = Struct.new(:status, :best_candidate, :all_candidates, keyword_init: true)

    RULES = [
      Rules::ExactInvoiceNumberRule,
      Rules::ExactRetailerCodeRule,
      Rules::ExactReferenceRule,
      Rules::RetailerAliasAndAmountRule,
      Rules::ExactAmountCustomerNameRule,
      Rules::MultiInvoiceSameCustomerRule,
      Rules::ExactAmountSingleOpenInvoiceRule
    ].freeze

    def self.call(txn, org = nil)
      new(txn, org || txn.organization).call
    end

    def initialize(txn, org)
      @txn = txn
      @org = org
    end

    def call
      all_candidates = collect_candidates

      # Persist all candidates; clear stale ones first
      @txn.candidates.destroy_all

      persisted = all_candidates.map do |c|
        BankTransactionMatch.create!(
          bank_transaction: @txn,
          customer_id:      c.customer_id,
          sales_invoice_id: c.invoice_id,
          score:            c.score,
          rule_code:        c.rule_code,
          explanation:      c.explanation,
          selected:         false
        )
      end

      best = persisted.max_by(&:score)

      if best
        best.update!(selected: true)
        status = determine_status(best.score)
      else
        status = "unmatched"
      end

      # Denormalize onto the transaction for fast queries
      @txn.update!(
        status:              status,
        match_score:         best&.score,
        match_rule:          best&.rule_code,
        matched_customer_id: best&.customer_id,
        matched_invoice_id:  best&.sales_invoice_id
      )

      Result.new(status: status, best_candidate: best, all_candidates: persisted)
    end

    private

    def collect_candidates
      raw = []

      RULES.each do |rule_class|
        rule_candidates = rule_class.call(@txn, @org)
        raw.concat(rule_candidates)
      rescue StandardError => e
        Rails.logger.error("[BankReconciliation::Matcher] Rule #{rule_class} failed: #{e.message}")
      end

      # Deduplicate by invoice_id keeping highest score
      raw
        .group_by(&:invoice_id)
        .values
        .map { |group| group.max_by(&:score) }
        .compact
    end

    def determine_status(score)
      if score >= AUTO_POST_THRESHOLD
        "auto_matched"
      elsif score >= SUGGEST_THRESHOLD
        "suggested"
      else
        "unmatched"
      end
    end
  end
end
