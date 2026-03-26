# Recalculates a CreditAccount's current_balance and overdue_amount
# from the live invoice ledger.
#
# Called after:
#   - Payment confirmed / reversed
#   - Invoice issued / voided
#   - Manual admin trigger
#
# Idempotent: safe to run multiple times; updates columns atomically.
#
class RecalculateCreditAccountJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  # @param credit_account_id [Integer]
  def perform(credit_account_id)
    account = CreditAccount.lock("FOR UPDATE").find(credit_account_id)

    invoices = account.customer
                      .sales_invoices
                      .where(organization: account.organization, branch: account.branch)
                      .where.not(status: %w[void draft])

    # Sum outstanding (issued + partially_paid)
    total_outstanding = invoices
                          .where(status: %w[issued partially_paid])
                          .sum("total_amount - COALESCE(paid_amount, 0)")

    # Overdue: outstanding invoices past their due_date
    overdue = invoices
                .where(status: %w[issued partially_paid])
                .where("due_date < ?", Date.current)
                .sum("total_amount - COALESCE(paid_amount, 0)")

    account.update!(
      current_balance: total_outstanding,
      overdue_amount:  [overdue, 0].max
    )

    Rails.logger.info(
      "[RecalculateCreditAccountJob] Account##{credit_account_id} " \
      "balance=#{total_outstanding} overdue=#{overdue}"
    )
  rescue => e
    Sentry.capture_exception(e) if defined?(Sentry)
    Rails.logger.error("[RecalculateCreditAccountJob] Failed for Account##{credit_account_id}: #{e.message}")
    raise
  end
end
