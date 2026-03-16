# frozen_string_literal: true

module BankReconciliation
  # Notifies finance/accounting team of suggested transaction matches
  # Called by BankReconciliationJob when a high-confidence match is found
  #
  # Theresholds:
  #   Score 95+: Auto-posted silently (no notification needed, just audit trail)
  #   Score 90-94: Auto-posted + notify admin (can undo within 1 hour)
  #   Score 80-89: Suggested for review (notify immediately, don't wait for batch)
  #
  class SuggestedMatchNotifier
    def self.call(txn:, organization:, match_score:, reason: nil)
      new(txn, organization, match_score, reason).call
    end

    def initialize(txn, organization, match_score, reason = nil)
      @txn = txn
      @organization = organization
      @match_score = match_score
      @reason = reason
    end

    def call
      return unless should_notify?

      notify_team
    end

    private

    def should_notify?
      # Only notify for suggested matches (80-94)
      @match_score >= 80 && @match_score < 95
    end

    def notify_team(options = {})
      accountants = find_finance_team
      return if accountants.empty?

      message = build_notification_message
      accountants.each do |accountant|
        send_notification(accountant, message)
      end
    end

    def find_finance_team
      # Find users with accounting/finance roles who should review transactions
      @organization.users.where(
        role: %w[owner admin manager], # Adjust based on actual role names
        active: true
      ).where.not(email: nil)
    end

    def build_notification_message
      customer_name = @txn.description.split(/[|,\/-]/).first&.strip || "Unknown"
      amount_formatted = format_amount(@txn.amount)

      {
        title: "Transaction Match Ready for Review",
        body: "₹#{amount_formatted} from #{customer_name} (matched with #{@match_score.round(0)}% confidence)",
        deep_link_url: "/banking/reconciliation?status=suggested&txn_id=#{@txn.id}"
      }
    end

    def send_notification(accountant, message)
      # In-app notification
      Notification.create(
        user: accountant,
        organization: @organization,
        title: message[:title],
        body: message[:body],
        notification_type: 'bank_reconciliation_suggested',
        deep_link_url: message[:deep_link_url],
        severity: 'medium'
      )

      # SMS (if enabled and phone available)
      send_sms(accountant, message) if accountant.phone.present?

      # Email (optional, less intrusive than SMS)
      # send_email(accountant, message) if accountant.email.present?
    rescue => error
      Rails.logger.warn(
        "[BankReconciliation::SuggestedMatchNotifier] " \
        "Failed to notify #{accountant.id}: #{error.message}"
      )
    end

    def send_sms(accountant, message)
      return unless TwilioClient.enabled?

      text = "Transaction ₹#{format_amount(@txn.amount)} matched (#{message[:body]}). Review: #{message[:deep_link_url]}"

      # Truncate to SMS limit
      if text.length > 160
        text = "₹#{format_amount(@txn.amount)} transaction matched. Review reconciliation."
      end

      TwilioClient.send_sms(
        phone_number: accountant.phone,
        message: text
      )
    rescue => error
      Rails.logger.warn(
        "[BankReconciliation::SuggestedMatchNotifier] " \
        "SMS send failed for #{accountant.id}: #{error.message}"
      )
    end

    def format_amount(amount)
      number_with_precision(amount, precision: 0)
    end
  end
end
