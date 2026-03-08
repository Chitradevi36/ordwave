module Accounting
  module Canonical
    # Maps a Payment (with allocations) to a canonical ReceiptVoucher.
    #
    # OMS Payment fields used:
    #   payment_number    -> voucher_number
    #   received_date     -> voucher_date
    #   customer.name     -> party_ledger_name
    #   payment_mode      -> receipt_ledger_name (resolved via LEDGER_MAP)
    #   amount            -> amount
    #   reference_number  -> reference_number
    #   notes             -> narration
    #   allocations (PaymentAllocation[]) -> bill_allocations
    #
    # Each PaymentAllocation has:
    #   allocated_amount, sales_invoice (with invoice_number, invoice_date)
    #
    # If payment has no allocations (unallocated/advance), produces one
    # BillAllocation with bill_type "on_account".
    class PaymentToReceiptVoucherMapper < BaseMapper
      # Maps OMS payment_mode to a canonical receipt ledger name.
      # These are defaults; provider adapters can override with AccountingMapping.
      RECEIPT_LEDGER_MAP = {
        "cash"          => "Cash",
        "bank_transfer" => "Bank Account",
        "upi"           => "UPI",
        "cheque"        => "Cheque",
        "neft"          => "Bank Account",
        "rtgs"          => "Bank Account",
        "adjustment"    => "Journal Adjustment"
      }.freeze

      def call
        payment = record

        voucher_number = require_present!(
          fetch_first_present(payment, :payment_number, :number, :code),
          "payment voucher_number"
        )

        amount = decimal!(fetch_first_present(payment, :amount))
        raise MappingError, "#{self.class.name}: payment amount must be > 0" unless amount.positive?

        party_name = require_present!(
          resolve_party_name(payment),
          "payment customer/party name"
        )

        ReceiptVoucher.new(
          voucher_type:         "receipt",
          voucher_number:       voucher_number,
          voucher_date:         fetch_first_present(payment, :received_date, :payment_date, :date),
          party_ledger_name:    party_name,
          receipt_ledger_name:  resolve_receipt_ledger(payment),
          amount:               amount,
          reference_number:     string_value(fetch_first_present(payment, :reference_number, :transaction_ref, :cheque_number, :utr)),
          narration:            build_narration(payment, party_name),
          bill_allocations:     build_bill_allocations(payment),
          metadata:             build_metadata(
            source_type:     "Payment",
            source_id:       payment.id,
            organization_id: payment.try(:organization_id),
            payment_mode:    payment.try(:payment_mode)
          )
        )
      end

      private

      def resolve_party_name(payment)
        party = fetch_first_present(payment, :customer, :retailer, :party)
        return nil unless party
        fetch_first_present(party, :name, :business_name)
      end

      def resolve_receipt_ledger(payment)
        mode = payment.try(:payment_mode).to_s
        RECEIPT_LEDGER_MAP.fetch(mode, "Bank Account")
      end

      def build_narration(payment, party_name)
        explicit = string_value(fetch_first_present(payment, :notes, :remarks, :narration))
        return explicit if explicit.present?

        mode = payment.try(:payment_mode).to_s.humanize
        "Payment received from #{party_name} via #{mode}".strip
      end

      def build_bill_allocations(payment)
        allocations = fetch_first_present(payment, :allocations, :payment_allocations) || []
        active_allocations = Array(allocations).select { |a| a.try(:status).to_s != "reversed" }

        if active_allocations.empty?
          # Unapplied / on-account payment
          return [
            BillAllocation.new(
              bill_name:      fetch_first_present(payment, :payment_number, :number),
              bill_type:      "on_account",
              amount:         decimal!(payment.try(:amount)),
              reference_date: fetch_first_present(payment, :received_date, :payment_date),
              notes:          "Unapplied advance / on-account payment"
            )
          ]
        end

        active_allocations.map do |alloc|
          invoice = alloc.try(:sales_invoice)
          BillAllocation.new(
            bill_name:      string_value(invoice&.try(:invoice_number) || alloc.try(:reference)),
            bill_type:      "against_ref",
            amount:         decimal!(alloc.try(:allocated_amount)),
            reference_date: invoice&.try(:invoice_date),
            notes:          nil
          )
        end
      end
    end
  end
end
