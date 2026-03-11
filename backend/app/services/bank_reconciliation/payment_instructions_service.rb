# frozen_string_literal: true

module BankReconciliation
  # Generates payment instruction text blocks for a SalesInvoice.
  # Optionally creates ExpectedPaymentReference records so UTR-based
  # auto-matching works when the customer pays.
  #
  # Usage:
  #   result = BankReconciliation::PaymentInstructionsService.call(
  #     invoice:      sales_invoice,
  #     bank_account: bank_account   # optional — uses org default if nil
  #   )
  #   result.text_block   # => String (ready to copy-paste into WhatsApp / email)
  #   result.references   # => Array<ExpectedPaymentReference>
  class PaymentInstructionsService
    Result = Struct.new(:text_block, :references, keyword_init: true)

    def self.call(invoice:, bank_account: nil)
      new(invoice: invoice, bank_account: bank_account).call
    end

    def initialize(invoice:, bank_account: nil)
      @invoice      = invoice
      @bank_account = bank_account || primary_bank_account
      @org          = invoice.organization
    end

    def call
      refs = create_references
      text = build_text_block(refs)
      Result.new(text_block: text, references: refs)
    end

    private

    def primary_bank_account
      BankAccount.active.where(organization: @org).order(:id).first
    end

    def create_references
      created = []

      # Invoice-number reference
      created << ExpectedPaymentReference.find_or_create_by!(
        organization:  @org,
        customer:      @invoice.customer,
        sales_invoice: @invoice,
        reference_type: :invoice_number,
        reference_value: @invoice.invoice_number.upcase
      ) { |r| r.status = :pending }

      # Customer-code reference (makes matching possible even without invoice number)
      if @invoice.customer.code.present?
        created << ExpectedPaymentReference.find_or_create_by!(
          organization:   @org,
          customer:       @invoice.customer,
          sales_invoice:  @invoice,
          reference_type: :customer_code,
          reference_value: @invoice.customer.code.upcase
        ) { |r| r.status = :pending }
      end

      created
    end

    def build_text_block(refs)
      lines = []
      lines << "---- Payment Instructions ----"

      if @bank_account
        lines << "Bank:           #{@bank_account.bank_name}"
        lines << "Account Name:   #{@bank_account.account_holder_name}"
        lines << "Account No:     #{masked_account_number}"
        lines << "IFSC:           #{@bank_account.ifsc_code}"
        lines << "Account Type:   #{@bank_account.account_type.humanize}" if @bank_account.respond_to?(:account_type)
      end

      lines << ""
      lines << "Invoice No:     #{@invoice.invoice_number}"
      lines << "Amount Due:     ₹#{format('%.2f', @invoice.outstanding_amount)}"
      lines << "Due Date:       #{@invoice.due_date&.strftime('%d %b %Y') || 'N/A'}"
      lines << ""
      lines << "IMPORTANT: When making payment, please include one of the"
      lines << "following references in the remarks/description field:"

      refs.each do |ref|
        lines << "  • #{ref.reference_value}  (#{ref.reference_type.humanize})"
      end

      if @invoice.customer.code.present?
        lines << "  • #{@invoice.customer.code}  (Retailer Code)"
      end

      lines << ""
      lines << "This helps us reconcile your payment automatically."
      lines << "------------------------------"

      lines.join("\n")
    end

    def masked_account_number
      return "N/A" unless @bank_account&.account_number.present?
      num = @bank_account.account_number.to_s
      "#{num[0..1]}#{'*' * [num.length - 4, 0].max}#{num[-2..]}"
    end
  end
end
