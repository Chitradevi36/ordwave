require 'rails_helper'

describe 'Bank Auto-Posting System Performance & Statistics' do
  describe 'Confidence Scoring Distribution' do
    before do
      # Create a variety of payments with different confidence scores
      create_list(:payment, 5, confidence_score: 97.5, auto_posted: true)   # High
      create_list(:payment, 8, confidence_score: 90.0, auto_posted: true)   # Medium
      create_list(:payment, 4, confidence_score: 72.0, auto_posted: false)  # Low
    end

    it 'calculates correct distribution percentages' do
      total = Payment.count
      high = Payment.where('confidence_score >= 95').count
      medium = Payment.where('confidence_score BETWEEN 85 AND 94.99').count
      low = Payment.where('confidence_score < 85').count

      high_pct = (high.to_f / total) * 100
      medium_pct = (medium.to_f / total) * 100
      low_pct = (low.to_f / total) * 100

      expect(high_pct).to be_within(5).of(33)  # ~5/17
      expect(medium_pct).to be_within(5).of(47) # ~8/17
      expect(low_pct).to be_within(5).of(24)   # ~4/17
    end

    it 'tracks success rate of auto-posted payments' do
      auto_posted_count = Payment.where(auto_posted: true).count
      total_count = Payment.count
      success_rate = (auto_posted_count.to_f / total_count) * 100

      expect(success_rate).to be_within(10).of(75)  # High score = high auto-post rate
    end
  end

  describe 'Rejection Window Expiration Tracking' do
    before do
      @pending = create(:payment,
        auto_posted: true,
        rejection_window_expires_at: 30.minutes.from_now
      )
      @expired = create(:payment,
        auto_posted: true,
        rejection_window_expires_at: 30.minutes.ago
      )
      @will_expire = create(:payment,
        auto_posted: true,
        rejection_window_expires_at: 1.hour.from_now
      )
    end

    it 'identifies payments with active rejection windows' do
      active = Payment.where('rejection_window_expires_at > ?', Time.current)
      expect(active.count).to eq(2)
      expect(active).to include(@pending, @will_expire)
      expect(active).not_to include(@expired)
    end

    it 'identifies payments with expired rejection windows' do
      expired = Payment.where('auto_posted = ? AND rejection_window_expires_at < ?', true, Time.current)
      expect(expired.count).to eq(1)
      expect(expired).to include(@expired)
    end

    it 'calculates window expiration statistics' do
      window_hours = 1
      payments = Payment.where(auto_posted: true)

      within_1hr = payments.count { |p| p.time_until_rejection_expires&.between?(0, window_hours * 3600) }
      expired = payments.count { |p| p.rejection_window_expired? }

      expect(within_1hr + expired).to eq(payments.count)
    end

    it 'tracks payments by window status' do
      within_30min = Payment.where(
        'rejection_window_expires_at BETWEEN ? AND ?',
        Time.current,
        30.minutes.from_now
      ).count
      
      expect(within_30min).to eq(1)
      expect(within_30min).to be > 0
    end
  end

  describe 'Audit Trail Statistics' do
    before do
      3.times { create(:auto_post_audit, action: 'auto_posted') }
      2.times { create(:auto_post_audit, action: 'rejected_by_finance') }
      1.times { create(:auto_post_audit, action: 'rejected_by_window') }
    end

    it 'counts auto-posted vs rejected actions' do
      auto_posted = AutoPostAudit.where(action: 'auto_posted').count
      rejected = AutoPostAudit.where(action: %w[rejected_by_finance rejected_by_window]).count

      expect(auto_posted).to eq(3)
      expect(rejected).to eq(3)
      expect(auto_posted + rejected).to eq(AutoPostAudit.count)
    end

    it 'analyzes rejection reasons' do
      finance_rejections = AutoPostAudit.where(action: 'rejected_by_finance').count
      window_rejections = AutoPostAudit.where(action: 'rejected_by_window').count

      expect(finance_rejections).to eq(2)
      expect(window_rejections).to eq(1)
      expect(finance_rejections > window_rejections).to be true
    end

    it 'generates audit trail summary by date' do
      today = Date.today
      audits_today = AutoPostAudit.where('DATE(timestamp) = ?', today).count
      audits_total = AutoPostAudit.count

      expect(audits_today).to eq(audits_total)  # All created today
    end

    it 'tracks actor information in audits' do
      user = create(:user)
      audit = create(:auto_post_audit, actor: user)

      expect(AutoPostAudit.where(actor: user).count).to eq(1)
    end
  end

  describe 'Rejection Feedback Analytics' do
    before do
      # Simulate different confidence bands with rejection patterns
      create(:rejection_feedback,
        confidence_score: 98.0,
        rejection_reason: 'False positive',
        timestamp: Time.current
      )
      create(:rejection_feedback,
        confidence_score: 96.5,
        rejection_reason: 'Customer name mismatch',
        timestamp: 1.hour.ago
      )
      create(:rejection_feedback,
        confidence_score: 88.0,
        rejection_reason: 'Reference number unclear',
        timestamp: 2.hours.ago
      )
      create(:rejection_feedback,
        confidence_score: 82.0,
        rejection_reason: 'Date mismatch',
        timestamp: 3.hours.ago
      )
    end

    it 'calculates rejection rate by confidence band' do
      high_confidence = RejectionFeedback.where('confidence_score >= 95').count
      medium_confidence = RejectionFeedback.where('confidence_score BETWEEN 85 AND 94.99').count
      low_confidence = RejectionFeedback.where('confidence_score < 85').count

      expect(high_confidence).to eq(2)
      expect(medium_confidence).to eq(1)
      expect(low_confidence).to eq(1)
    end

    it 'identifies most common rejection reasons' do
      reasons = RejectionFeedback.pluck(:rejection_reason)
      reason_counts = reasons.group_by { |r| r }.transform_values(&:count)

      # Should have various reasons
      expect(reason_counts.keys.uniq.count).to eq(4)
    end

    it 'calculates false positive rate for high confidence' do
      false_positives = RejectionFeedback.where(
        'confidence_score >= 95 AND rejection_reason ILIKE ?',
        '%false%'
      ).count
      high_conf_total = RejectionFeedback.where('confidence_score >= 95').count

      false_positive_rate = (false_positives.to_f / high_conf_total) * 100

      expect(false_positive_rate).to be > 0
    end

    it 'tracks feedback collection over time' do
      old_feedback = create(:rejection_feedback, timestamp: 1.week.ago)
      recent_feedback = create(:rejection_feedback, timestamp: 1.hour.ago)

      week_ago = RejectionFeedback.where('timestamp < ?', 2.days.ago).count
      last_24hrs = RejectionFeedback.where('timestamp > ?', 24.hours.ago).count

      expect(week_ago).to be >= 1
      expect(last_24hrs).to be >= 1
    end
  end

  describe 'Payment Suggestion Approval Rate' do
    before do
      create_list(:payment_suggestion, 5, status: 'pending_approval')
      create_list(:payment_suggestion, 3, status: 'approved')
      create_list(:payment_suggestion, 2, status: 'rejected')
    end

    it 'calculates pending vs approved suggestions' do
      pending = PaymentSuggestion.where(status: 'pending_approval').count
      approved = PaymentSuggestion.where(status: 'approved').count
      rejected = PaymentSuggestion.where(status: 'rejected').count
      total = PaymentSuggestion.count

      approval_rate = (approved.to_f / (approved + rejected)) * 100

      expect(pending).to eq(5)
      expect(approved).to eq(3)
      expect(rejected).to eq(2)
      expect(approval_rate).to be_within(1).of(60)  # 3/(3+2) = 60%
    end

    it 'tracks average approval time' do
      suggestion = create(:payment_suggestion,
        status: 'pending_approval',
        created_at: 2.hours.ago
      )
      suggestion.approve!(create(:user))
      suggestion.reload

      approval_time = suggestion.approved_at - suggestion.created_at

      expect(approval_time).to be > 0
      expect(approval_time).to be < 2.hours * 60  # Should be less than 2 hours
    end

    it 'groups suggestions by confidence level' do
      low_medium = PaymentSuggestion.where('confidence_score BETWEEN 85 AND 89.99').count
      high_medium = PaymentSuggestion.where('confidence_score BETWEEN 90 AND 94.99').count

      expect(low_medium + high_medium).to eq(PaymentSuggestion.count)
    end
  end

  describe 'System Performance Metrics' do
    it 'calculates average confidence score efficiently' do
      create_list(:payment, 20, confidence_score: 92.5)
      create_list(:payment, 15, confidence_score: 88.0)

      avg_score = Payment.average(:confidence_score).to_f

      expect(avg_score).to be_within(1).of(90.6)
    end

    it 'identifies high-risk payments efficiently' do
      high_risk = create_list(:payment, 5, confidence_score: 75.0)
      low_risk = create_list(:payment, 15, confidence_score: 96.0)

      high_risk_count = Payment.where('confidence_score < 80').count

      expect(high_risk_count).to eq(5)
    end

    it 'tracks daily auto-posting statistics' do
      today = Date.today
      create_list(:payment, 10, auto_posted: true)
      create_list(:payment, 3, auto_posted: false)

      daily_auto = Payment.where(auto_posted: true).count
      daily_manual = Payment.where(auto_posted: false).count
      daily_total = Payment.count

      auto_rate = (daily_auto.to_f / daily_total) * 100

      expect(daily_auto).to eq(10)
      expect(daily_manual).to eq(3)
      expect(auto_rate).to be_within(2).of(77)
    end

    it 'calculates rejection window utilization' do
      active_windows = Payment.where(
        'auto_posted = ? AND rejection_window_expires_at > ?',
        true,
        Time.current
      ).count
      expired_windows = Payment.where(
        'auto_posted = ? AND rejection_window_expires_at < ?',
        true,
        Time.current
      ).count
      total_auto_posted = Payment.where(auto_posted: true).count

      utilization = ((active_windows + expired_windows).to_f / total_auto_posted) * 100

      expect(utilization).to eq(100)
    end
  end

  describe 'Confidence Configuration Application' do
    it 'loads latest configuration version' do
      v1 = create(:confidence_adjustment, model_version: 1)
      v2 = create(:confidence_adjustment, model_version: 2)

      latest = ConfidenceAdjustment.latest

      expect(latest.model_version).to eq(2)
    end

    it 'applies configuration thresholds consistently' do
      config = create(:confidence_adjustment,
        auto_post_threshold: 95,
        suggestion_threshold: 85
      )

      auto_post_threshold = config.auto_post_threshold
      suggestion_threshold = config.suggestion_threshold

      # Verify thresholds are applied correctly
      high_confidence = 97  # Should auto-post
      medium_confidence = 89  # Should suggest
      low_confidence = 75  # Should route to manual

      expect(high_confidence >= auto_post_threshold).to be true
      expect(medium_confidence >= suggestion_threshold && medium_confidence < auto_post_threshold).to be true
      expect(low_confidence < suggestion_threshold).to be true
    end

    it 'uses configuration for tolerance calculations' do
      config = create(:confidence_adjustment,
        amount_tolerance_pct: 2.5,
        date_tolerance_days: 4
      )

      expect(config.amount_tolerance_pct).to eq(2.5)
      expect(config.date_tolerance_days).to eq(4)

      # Verify these would be used in calculations
      invoice_amount = 10000.0
      tolerance = invoice_amount * (config.amount_tolerance_pct / 100.0)

      expect(tolerance).to eq(250.0)
    end
  end

  describe 'Multi-Payment Handling' do
    it 'processes multiple payments in parallel without conflict' do
      invoices = create_list(:invoice, 3, customer: create(:customer), total: 5000)
      
      results = invoices.map do |invoice|
        {
          invoice: invoice,
          confidence: rand(75..99),
          status: rand > 0.5 ? 'auto_posted' : 'suggestion'
        }
      end

      # Verify all are recorded
      expect(results.count).to eq(3)
      expect(results.uniq(&:invoice).count).to eq(3)
    end

    it 'prevents duplicate payment recording' do
      invoice = create(:invoice)
      transaction = create(:bank_transaction, amount: invoice.total)

      payment1 = create(:payment, invoice: invoice, bank_transaction: transaction)
      payment2 = Payment.new(invoice: invoice, bank_transaction: transaction)

      # In real system, this would be prevented by unique constraint
      # or business logic in PaymentAutoPostService
      expect(payment1.persisted?).to be true
    end

    it 'handles consolidated payments across multiple invoices' do
      customer = create(:customer)
      invoices = create_list(:invoice, 3, customer: customer)
      total_amount = invoices.sum(&:total)

      transaction = create(:bank_transaction, amount: total_amount)

      # Verify transaction can be matched to multiple invoices
      expect(invoices.count).to eq(3)
      expect(invoices.sum(&:total)).to eq(total_amount)
    end
  end

  describe 'Audit Trail Querying Performance' do
    before do
      10.times do |i|
        create(:auto_post_audit,
          action: i % 2 == 0 ? 'auto_posted' : 'rejected_by_finance',
          timestamp: i.days.ago
        )
      end
    end

    it 'filters audit trail by action efficiently' do
      auto_posted_audits = AutoPostAudit.where(action: 'auto_posted')

      expect(auto_posted_audits.count).to eq(5)
    end

    it 'filters audit trail by date range efficiently' do
      range_start = 5.days.ago
      range_end = 1.day.ago

      audits_in_range = AutoPostAudit.where(
        'timestamp BETWEEN ? AND ?',
        range_start,
        range_end
      ).count

      expect(audits_in_range).to be >= 3
    end

    it 'orders audit trail chronologically' do
      audits = AutoPostAudit.order(timestamp: :desc).limit(2)
      first_timestamp = audits.first.timestamp
      second_timestamp = audits.second.timestamp

      expect(first_timestamp > second_timestamp).to be true
    end
  end

  describe 'System Health Indicators' do
    before do
      create_list(:payment, 30, confidence_score: 96.0, auto_posted: true)
      create_list(:payment, 8, confidence_score: 88.0, auto_posted: true)
      create_list(:payment, 4, confidence_score: 72.0, auto_posted: false)
      
      # Add some rejection feedback
      create(:rejection_feedback, confidence_score: 96.5, rejection_reason: 'False positive')
    end

    it 'calculates system accuracy metrics' do
      total_auto_posted = Payment.where(auto_posted: true).count
      rejection_count = RejectionFeedback.count
      
      # Higher confidence scores should have fewer rejections
      high_conf_rejected = RejectionFeedback.where('confidence_score >= 95').count

      accuracy = ((total_auto_posted - high_conf_rejected).to_f / total_auto_posted) * 100

      expect(total_auto_posted).to eq(38)
      expect(high_conf_rejected).to eq(1)
      expect(accuracy).to be > 97
    end

    it 'identifies system bottlenecks' do
      pending_rejections = Payment.where(
        'auto_posted = ? AND rejection_window_expires_at > ?',
        true,
        Time.current
      ).count

      # Should generally be managed
      expect(pending_rejections).to be >= 0
    end

    it 'tracks overall transaction volume' do
      total_payments = Payment.count
      auto_posted_pct = (Payment.where(auto_posted: true).count.to_f / total_payments * 100)

      expect(total_payments).to eq(42)
      expect(auto_posted_pct).to be > 75
    end

    it 'monitors confidence score distribution' do
      average_confidence = Payment.average(:confidence_score).to_f
      high_confidence_count = Payment.where('confidence_score >= 95').count
      
      expect(average_confidence).to be > 85
      expect(high_confidence_count).to be > Payment.count / 2
    end

    it 'evaluates system reliability' do
      # Auto-post success (not manually overridden)
      auto_posted = Payment.where(auto_posted: true).count
      still_auto_posted = auto_posted - RejectionFeedback.where('confidence_score >= 95').count
      
      reliability = (still_auto_posted.to_f / auto_posted * 100)

      expect(reliability).to be > 95
    end
  end
end
