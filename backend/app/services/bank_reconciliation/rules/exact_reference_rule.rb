# frozen_string_literal: true

module BankReconciliation
  module Rules
    # Rule 3 — Exact UTR / reference match against ExpectedPaymentReferences
    # Score: 100 — a UTR pre-registered by the finance team is the gold standard
    class ExactReferenceRule
      RULE_CODE = "exact_reference"

      Candidate = Struct.new(:customer_id, :invoice_id, :score, :rule_code, :explanation, keyword_init: true)

      def self.call(txn, org)
        new(txn, org).call
      end

      def initialize(txn, org)
        @txn = txn
        @org = org
      end

      def call
        candidates = []
        lookups = build_lookups
        return [] if lookups.empty?

        lookups.each do |value|
          ref = ExpectedPaymentReference
                  .for_org(@org)
                  .pending
                  .by_value(value)
                  .first
          next unless ref

          candidates << Candidate.new(
            customer_id: ref.customer_id,
            invoice_id:  ref.sales_invoice_id,
            score:       100.0,
            rule_code:   RULE_CODE,
            explanation: {
              reference_type:  ref.reference_type,
              reference_value: value,
              strategy:        "expected_payment_reference_hit"
            }
          )
        end

        # Also match UTR directly on existing Payments to catch duplicate submissions
        if @txn.utr_number.present?
          existing = Payment
                       .for_org(@org)
                       .where("UPPER(reference_number) = ?", @txn.utr_number.upcase)
                       .first
          if existing
            # This UTR was already posted — flag as potential duplicate
            candidates << Candidate.new(
              customer_id: existing.customer_id,
              invoice_id:  nil,
              score:       60.0,   # Low score — likely duplicate, needs human review
              rule_code:   "existing_payment_utr",
              explanation: {
                utr:              @txn.utr_number,
                existing_payment: existing.payment_number,
                strategy:         "utr_matches_existing_payment_possible_duplicate"
              }
            )
          end
        end

        candidates
      end

      private

      def build_lookups
        values = []
        values << @txn.utr_number.upcase       if @txn.utr_number.present?
        values << @txn.reference_number.upcase if @txn.reference_number.present?
        (@txn.match_meta&.dig("utr_candidates") || []).each { |u| values << u.upcase }
        values.uniq
      end
    end
  end
end
