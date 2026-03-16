class BankReconciliationJob
  include Sidekiq::Job
  sidekiq_options queue: 'default', retry: 3

  # Scheduled daily at 5 AM via config/sidekiq.yml
  def perform
    Organization.where(active: true).find_each do |organization|
      process_organization(organization)
    end
  rescue => error
    log_error("BankReconciliationJob failed", error)
    raise error # Sidekiq will retry
  end

  private

  def process_organization(organization)
    # Find all unmatched bank transactions
    unmatched_transactions = BankTransaction
                              .for_org(organization)
                              .unmatched
                              .where('txn_date >= ?', 30.days.ago) # Only recent transactions
                              .order(txn_date: :asc)

    return if unmatched_transactions.empty?

    stats = {
      total: unmatched_transactions.count,
      matched: 0,
      auto_posted: 0,
      suggested: 0,
      errors: 0
    }

    unmatched_transactions.find_each do |txn|
      process_transaction(txn, organization, stats)
    end

    # Alert if there are transactions needing review
    alert_pending_review(organization, stats) if stats[:suggested] > 0
  rescue => error
    log_error("Error processing organization #{organization.id}", error)
  end

  def process_transaction(txn, organization, stats)
    # Run the matcher
    result = BankReconciliation::Matcher.call(txn, organization)

    case result.status
    when 'auto_matched'
      # Auto-post the transaction
      post_transaction(txn, result.best_candidate, organization, stats)
      stats[:auto_posted] += 1
      stats[:matched] += 1

    when 'suggested'
      # Update status and notify finance team immediately (don't wait for batch)
      txn.update(status: 'suggested')
      stats[:suggested] += 1

      # Send immediate notification so accountant can review, not wait for morning
      BankReconciliation::SuggestedMatchNotifier.call(
        txn: txn,
        organization: organization,
        match_score: result.best_candidate.score
      )

    when 'unmatched'
      # Update status to unmatched, keep for manual review
      txn.update(status: 'unmatched')
    end
  rescue StandardError => error
    log_error("Error processing transaction #{txn.id}", error)
    stats[:errors] += 1
  end

  def post_transaction(txn, best_candidate, organization, stats)
    # Prepare allocation data from the matched candidate
    allocations = if best_candidate.sales_invoice_id.present?
                    [{
                      invoice_id: best_candidate.sales_invoice_id,
                      amount: txn.amount
                    }]
                  else
                    [] # No allocation if no invoice
                  end

    # Post via BankReconciliation::PostingService
    result = BankReconciliation::PostingService.call(
      bank_transaction: txn,
      allocations: allocations,
      reviewed_by: nil # System-posted by background job
    )

    unless result.success?
      log_error("Failed to post transaction #{txn.id}: #{result.errors.join(', ')}", nil)
      return
    end

    # Mark the transaction as matched
    txn.update(
      status: 'matched',
      matched_customer_id: best_candidate.customer_id,
      matched_invoice_id: best_candidate.sales_invoice_id,
      matched_payment_id: result.payment.id,
      matched_at: Time.current
    )

    # Alert admins about auto-posted transaction
    send_auto_post_notification(txn, result.payment, organization)
  rescue => error
    log_error("Error posting transaction #{txn.id}", error)
  end

  def alert_pending_review(organization, stats)
    # Notify admins that there are transactions pending review
    admins = organization.users.where(role: %w[owner admin])
    
    return if admins.empty?

    subject = "[#{organization.name}] Bank Reconciliation: #{stats[:suggested]} Transactions Awaiting Review"
    body = reconciliation_alert_body(organization, stats)

    admins.each do |admin|
      # Send in-app notification
      Notification.create(
        user: admin,
        organization: organization,
        title: 'Bank Reconciliation Review Needed',
        body: "#{stats[:suggested]} bank transactions are suggested for matching and need your review.",
        notification_type: 'bank_reconciliation_review',
        deep_link_url: "/banking/reconciliation?status=suggested"
      )
    end

    # Optionally send email
    admins.each do |admin|
      # BankReconciliationMailer.pending_review(admin, organization, stats).deliver_later
    end
  rescue => error
    log_error("Error alerting pending review", error)
  end

  def send_auto_post_notification(txn, payment, organization)
    # Log the auto-posted transaction for audit
    AuditLog.create(
      organization_id: organization.id,
      entity_type: 'BankTransaction',
      entity_id: txn.id,
      action: 'auto_posted_from_bank_reconciliation',
      details: {
        amount: txn.amount,
        matched_customer_id: txn.matched_customer_id,
        matched_invoice_id: txn.matched_invoice_id,
        payment_id: payment.id,
        triggered_by: 'BankReconciliationJob'
      }
    )
  rescue => error
    log_error("Error creating audit log for transaction #{txn.id}", error)
  end

  def reconciliation_alert_body(organization, stats)
    lines = [
      "Bank Reconciliation Summary for #{Date.current.strftime('%B %d, %Y')}:",
      "",
      "• Total Transactions Processed: #{stats[:total]}",
      "• Auto-Matched & Posted: #{stats[:auto_posted]}",
      "• Suggested for Review: #{stats[:suggested]}",
      "• Errors: #{stats[:errors]}",
      "",
      "ACTION REQUIRED: #{stats[:suggested]} transactions are awaiting your review.",
      "Please review and confirm matches to complete reconciliation.",
      "",
      "Review transactions: [Dashboard Link]"
    ]
    lines.join("\n")
  end

  def log_info(message)
    Rails.logger.info({
      job: 'BankReconciliationJob',
      message: message,
      timestamp: Time.current
    }.to_json)
  end

  def log_error(message, error)
    Rails.logger.error({
      job: 'BankReconciliationJob',
      message: message,
      error: error&.message,
      backtrace: error&.backtrace&.[](0..4)
    }.to_json)
  end
end
