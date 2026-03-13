# frozen_string_literal: true

module CreditNotes
  # Applies a credit note to one or more sales invoices,
  # reducing the invoice outstanding amount and tracking the application.
  #
  # Usage:
  #   result = CreditNotes::ApplyToInvoice.call(
  #     actor: current_user,
  #     credit_note: cn,
  #     applications: [
  #       { sales_invoice_id: 123, amount: 500.00 },
  #       { sales_invoice_id: 456, amount: 200.00 }
  #     ]
  #   )
  #
  class ApplyToInvoice
    Result = Struct.new(:success?, :credit_note, :applications, :errors)

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(actor:, credit_note:, applications:)
      @actor        = actor
      @credit_note  = credit_note
      @applications = Array(applications)
    end

    def call
      # Pre-flight checks
      unless @credit_note.status == 'issued'
        return Result.new(false, @credit_note, [],
                          ['Credit note must be in issued status'])
      end

      if @credit_note.unapplied_amount.to_d <= 0
        return Result.new(false, @credit_note, [],
                          ['Credit note has no unapplied balance remaining'])
      end

      total_requested = @applications.sum { |a| a[:amount].to_d }
      if total_requested > @credit_note.unapplied_amount.to_d
        return Result.new(false, @credit_note, [],
                          ["Total application (#{total_requested}) exceeds unapplied balance (#{@credit_note.unapplied_amount})"])
      end

      created_applications = []

      ActiveRecord::Base.transaction do
        @applications.each do |app_attrs|
          attrs = app_attrs.is_a?(Hash) ? app_attrs.symbolize_keys : app_attrs.to_h.deep_symbolize_keys
          invoice = SalesInvoice.find(attrs[:sales_invoice_id])

          # Verify same customer
          unless invoice.customer_id == @credit_note.customer_id
            raise "Invoice #{invoice.invoice_number} belongs to a different customer"
          end

          amount = attrs[:amount].to_d

          if amount > invoice.outstanding_amount.to_d
            raise "Amount #{amount} exceeds invoice #{invoice.invoice_number} outstanding (#{invoice.outstanding_amount})"
          end

          application = CreditNoteApplication.create!(
            credit_note:   @credit_note,
            sales_invoice: invoice,
            applied_by:    @actor,
            amount:        amount,
            status:        'active'
          )

          # Update invoice paid/outstanding
          new_outstanding = (invoice.outstanding_amount.to_d - amount).round(2)
          new_paid        = (invoice.paid_amount.to_d + amount).round(2)
          new_status      = new_outstanding <= 0 ? 'paid' : 'partially_paid'
          # Only move forward in status — never downgrade a paid invoice
          new_status = invoice.status if invoice.paid?
          invoice.update!(
            paid_amount:        new_paid,
            outstanding_amount: new_outstanding,
            status:             new_status
          )

          created_applications << application
        end

        # Update credit note applied/unapplied amounts
        total_applied = created_applications.sum(&:amount).to_d
        @credit_note.update!(
          applied_amount:   (@credit_note.applied_amount.to_d + total_applied).round(2),
          unapplied_amount: (@credit_note.unapplied_amount.to_d - total_applied).round(2)
        )

        # Log audit
        Credit::AuditLogger.log(
          actor:        @actor,
          organization: @credit_note.organization,
          auditable:    @credit_note,
          action:       'credit_note_applied',
          changes:      {
            applications: created_applications.map { |a|
              { invoice_id: a.sales_invoice_id, amount: a.amount.to_f }
            },
            unapplied_remaining: @credit_note.unapplied_amount.to_f
          }
        )
      end

      Result.new(true, @credit_note.reload, created_applications, [])
    rescue ActiveRecord::RecordNotFound => e
      Result.new(false, @credit_note, [], ["Invoice not found: #{e.message}"])
    rescue StandardError => e
      Result.new(false, @credit_note, [], [e.message])
    end
  end
end
