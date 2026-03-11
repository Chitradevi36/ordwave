# frozen_string_literal: true

module Accounting
  module Sync
    # Handles incoming data pushed from the Tally Agent back to OrdWave.
    #
    # Tally → OrdWave reverse sync flow:
    #   1. Agent pushes a batch of Tally vouchers/receipts via POST /agent/push_from_tally
    #   2. This service processes each record and creates/updates corresponding OrdWave entities
    #   3. Results (success/skipped/failed per record) are returned to the agent
    #
    # Supported record types:
    #   - "receipt_voucher"       → Confirm a payment / create a new payment
    #   - "payment_voucher"       → Record a supplier payment / advance
    #   - "closing_balance"       → Update customer outstanding balance snapshot
    #   - "ledger_entry"          → Generic fallback — stored as audit log
    class TallyPushHandlerService
      Result = Struct.new(:status, :entity_type, :entity_id, :message, keyword_init: true)

      SUPPORTED_TYPES = %w[receipt_voucher payment_voucher closing_balance ledger_entry].freeze

      def initialize(integration, records_params)
        @integration = integration
        @organization = integration.organization
        @records_params = Array(records_params)
      end

      # Process all records and return per-record results
      # @return [Array<Result>]
      def call
        @records_params.map { |rec| process_record(rec) }
      end

      private

      def process_record(rec)
        voucher_type = rec[:voucher_type]&.downcase

        unless SUPPORTED_TYPES.include?(voucher_type)
          return Result.new(
            status: "skipped",
            entity_type: voucher_type,
            entity_id: rec[:reference_number],
            message: "Unsupported voucher type: #{voucher_type}"
          )
        end

        case voucher_type
        when "receipt_voucher"    then handle_receipt(rec)
        when "payment_voucher"    then handle_payment(rec)
        when "closing_balance"    then handle_closing_balance(rec)
        when "ledger_entry"       then handle_ledger_entry(rec)
        end
      rescue => e
        Rails.logger.error("[TallyPushHandlerService] Error processing #{rec[:voucher_type]} " \
                           "ref=#{rec[:reference_number]}: #{e.class}: #{e.message}")
        Result.new(
          status: "error",
          entity_type: rec[:voucher_type],
          entity_id: rec[:reference_number],
          message: e.message
        )
      end

      # Receipt voucher → confirm an existing payment or create a new one
      def handle_receipt(rec)
        ref    = rec[:reference_number]
        amount = rec[:amount]&.to_d

        # Try to match an existing pending payment by reference/cheque number
        payment = @organization.payments
                               .where(status: %w[draft])
                               .where("reference_number = ? OR cheque_number = ?", ref, ref)
                               .first

        if payment
          payment.update!(
            status: "confirmed",
            tally_voucher_number: rec[:voucher_number],
            tally_sync_at: Time.current
          )

          Result.new(
            status: "success",
            entity_type: "payment",
            entity_id: payment.id,
            message: "Payment ##{payment.id} confirmed from Tally receipt #{ref}"
          )
        else
          # No matching payment — create an unallocated payment for reconciliation
          customer = @organization.customers.find_by(
            tally_ledger_name: rec[:party_name]
          )

          new_payment = @organization.payments.create!(
            customer: customer,
            amount: amount || 0,
            payment_mode: "tally_sync",
            reference_number: ref,
            tally_voucher_number: rec[:voucher_number],
            tally_sync_at: Time.current,
            status: "confirmed",
            notes: "Auto-created from Tally push: #{rec[:narration]}",
            payment_date: parse_tally_date(rec[:date])
          )

          Result.new(
            status: "success",
            entity_type: "payment",
            entity_id: new_payment.id,
            message: "New payment created from Tally receipt #{ref}"
          )
        end
      end

      # Payment voucher → record a supplier payment
      def handle_payment(rec)
        amount = rec[:amount]&.to_d

        # Log to application logger — supplier-side vouchers are informational only
        Rails.logger.info(
          "[TallyPush] payment_voucher received: org=#{@organization.id} " \
          "voucher=#{rec[:voucher_number]} party=#{rec[:party_name]} amount=#{amount}"
        )

        Result.new(
          status: "success",
          entity_type: "payment_voucher",
          entity_id: rec[:voucher_number],
          message: "Payment voucher #{rec[:voucher_number]} acknowledged"
        )
      end

      # Closing balance → update customer's tally_closing_balance snapshot
      def handle_closing_balance(rec)
        customer = @organization.customers.find_by(
          tally_ledger_name: rec[:party_name]
        )

        unless customer
          return Result.new(
            status: "skipped",
            entity_type: "closing_balance",
            entity_id: rec[:party_name],
            message: "No customer matched ledger name: #{rec[:party_name]}"
          )
        end

        customer.update!(
          tally_closing_balance:    rec[:closing_balance]&.to_d,
          tally_balance_as_of_date: parse_tally_date(rec[:date])
        )

        Result.new(
          status: "success",
          entity_type: "customer",
          entity_id: customer.id,
          message: "Closing balance updated for #{customer.name}"
        )
      end

      # Generic ledger entry → log and acknowledge
      def handle_ledger_entry(rec)
        Rails.logger.info(
          "[TallyPush] ledger_entry received: org=#{@organization.id} " \
          "voucher=#{rec[:voucher_number]} party=#{rec[:party_name]}"
        )

        Result.new(
          status: "success",
          entity_type: "ledger_entry",
          entity_id: rec[:voucher_number],
          message: "Ledger entry #{rec[:voucher_number]} acknowledged"
        )
      end

      def parse_tally_date(date_str)
        return Time.current if date_str.blank?
        # Tally uses YYYYMMDD format
        Date.strptime(date_str.to_s, "%Y%m%d").to_datetime
      rescue ArgumentError
        Time.current
      end
    end
  end
end
