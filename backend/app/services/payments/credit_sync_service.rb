module Payments
  # Recalculates and persists a customer's credit account balance based on:
  #   credit_used = sum(issued/partially_paid invoice grand_totals)
  #               - sum(confirmed payment allocated amounts)
  #               - sum(issued credit note totals)
  #
  # Usage:
  #   Payments::CreditSyncService.call(customer: customer, organization: org)
  class CreditSyncService
    def self.call(customer:, organization:)
      new(customer: customer, organization: organization).call
    end

    def initialize(customer:, organization:)
      @customer     = customer
      @organization = organization
    end

    def call
      account = CreditAccount.find_by(customer: @customer, organization: @organization)
      return unless account

      invoice_total = SalesInvoice
        .where(customer: @customer, organization: @organization)
        .where(status: %w[issued partially_paid])
        .where(deleted_at: nil)
        .sum(:grand_total)

      payment_total = Payment
        .joins(:allocations)
        .where(customer: @customer, organization: @organization, status: 'confirmed')
        .sum('payment_allocations.allocated_amount')

      credit_note_total = CreditNote
        .where(customer: @customer, organization: @organization, status: 'issued')
        .sum(:total)

      new_balance = [invoice_total - payment_total - credit_note_total, 0].max.round(2)

      updates = {
        current_balance:  new_balance,
        available_credit: [account.credit_limit - new_balance, 0].max.round(2)
      }

      # HIGH-05: Auto-clear collection_first and hold_required when balance reaches
      # zero so subsequent orders no longer go on hold without manual intervention.
      if new_balance.zero?
        updates[:collection_first] = false if account.collection_first?
        updates[:hold_required]    = false if account.hold_required?
      end

      account.update_columns(**updates)

      account
    end
  end
end
