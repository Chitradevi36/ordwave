require 'rails_helper'

describe 'Bank Auto-Posting Models Integration' do
  let(:customer) { create(:customer) }
  let(:invoice) { create(:invoice, customer: customer, total: 10000) }
  let(:user) { create(:user, role: :finance_manager) }

  describe 'AutoPostAudit Model' do
    let(:payment) { create(:payment, auto_posted: true) }
    let(:transaction) { create(:bank_transaction) }

    it 'creates audit with auto_posted action' do
      audit = AutoPostAudit.create!(
        payment: payment,
        bank_transaction: transaction,
        action: 'auto_posted',
        timestamp: Time.current,
        confidence_breakdown: { score: 97.5 }
      )

      expect(audit).to be_persisted
      expect(audit.auto_posted?).to be true
      expect(audit.rejected?).to be false
    end

    it 'creates audit with rejection action' do
      audit = AutoPostAudit.create!(
        payment: payment,
        action: 'rejected_by_finance',
        timestamp: Time.current
      )

      expect(audit.auto_posted?).to be false
      expect(audit.rejected?).to be true
    end

    it 'validates action presence' do
      audit = AutoPostAudit.new(
        payment: payment,
        timestamp: Time.current,
        action: nil
      )

      expect(audit).not_to be_valid
      expect(audit.errors[:action]).to be_present
    end

    it 'validates timestamp presence' do
      audit = AutoPostAudit.new(
        payment: payment,
        action: 'auto_posted',
        timestamp: nil
      )

      expect(audit).not_to be_valid
      expect(audit.errors[:timestamp]).to be_present
    end

    it 'validates timestamp not in future' do
      audit = AutoPostAudit.new(
        payment: payment,
        action: 'auto_posted',
        timestamp: 1.hour.from_now
      )

      expect(audit).not_to be_valid
      expect(audit.errors[:timestamp]).to be_present
    end

    it 'scopes auto_posted correctly' do
      audit1 = create(:auto_post_audit, action: 'auto_posted')
      audit2 = create(:auto_post_audit, action: 'rejected_by_finance')

      expect(AutoPostAudit.auto_posted.count).to be >= 1
      expect(AutoPostAudit.auto_posted).to include(audit1)
      expect(AutoPostAudit.auto_posted).not_to include(audit2)
    end

    it 'scopes rejected correctly' do
      audit1 = create(:auto_post_audit, action: 'auto_posted')
      audit2 = create(:auto_post_audit, action: 'rejected_by_finance')
      audit3 = create(:auto_post_audit, action: 'rejected_by_window')

      expect(AutoPostAudit.rejected.count).to be >= 2
      expect(AutoPostAudit.rejected).to include(audit2)
      expect(AutoPostAudit.rejected).to include(audit3)
      expect(AutoPostAudit.rejected).not_to include(audit1)
    end

    it 'scopes by date range' do
      old_audit = create(:auto_post_audit, timestamp: 10.days.ago)
      recent_audit = create(:auto_post_audit, timestamp: Time.current)

      audits = AutoPostAudit.for_date_range(5.days.ago, Date.today)
      expect(audits).to include(recent_audit)
      expect(audits).not_to include(old_audit)
    end

    it 'orders recent first' do
      audit1 = create(:auto_post_audit, timestamp: 1.hour.ago)
      audit2 = create(:auto_post_audit, timestamp: Time.current)

      audits = AutoPostAudit.recent
      expect(audits.first.id).to eq(audit2.id)
      expect(audits.last.id).to eq(audit1.id)
    end
  end

  describe 'RejectionFeedback Model' do
    let(:payment) { create(:payment, confidence_score: 88.5) }

    it 'creates feedback entry' do
      feedback = RejectionFeedback.create!(
        payment: payment,
        confidence_score: 88.5,
        rejection_reason: 'Customer name mismatch',
        timestamp: Time.current
      )

      expect(feedback).to be_persisted
      expect(feedback.payment).to eq(payment)
    end

    it 'validates confidence_score presence' do
      feedback = RejectionFeedback.new(
        payment: payment,
        rejection_reason: 'Test',
        timestamp: Time.current,
        confidence_score: nil
      )

      expect(feedback).not_to be_valid
    end

    it 'validates timestamp presence' do
      feedback = RejectionFeedback.new(
        payment: payment,
        confidence_score: 88.5,
        rejection_reason: 'Test',
        timestamp: nil
      )

      expect(feedback).not_to be_valid
    end

    it 'scopes by reason' do
      feedback1 = create(:rejection_feedback, rejection_reason: 'Name mismatch')
      feedback2 = create(:rejection_feedback, rejection_reason: 'Amount mismatch')

      expect(RejectionFeedback.by_reason('Name mismatch')).to include(feedback1)
      expect(RejectionFeedback.by_reason('Name mismatch')).not_to include(feedback2)
    end

    it 'calculates false positive rate by confidence band' do
      # Create rejections across different confidence bands
      create(:rejection_feedback, confidence_score: 97.5, rejection_reason: 'False positive')  # 95-100%
      create(:rejection_feedback, confidence_score: 92.0, rejection_reason: 'False positive')  # 85-95%
      create(:rejection_feedback, confidence_score: 75.0, rejection_reason: 'Correct')         # 70-85%

      bands = RejectionFeedback.false_positive_rate_by_confidence_band(1.day.ago, Date.today)

      expect(bands).to have_key('95-100%')
      expect(bands).to have_key('85-95%')
      expect(bands['95-100%'][:reasons]['False positive']).to be >= 1
    end
  end

  describe 'ConfidenceAdjustment Model' do
    it 'stores configuration with model version' do
      config = ConfidenceAdjustment.create!(
        model_version: 1,
        amount_tolerance_pct: 2.0,
        date_tolerance_days: 3,
        customer_fuzzy_minimum: 0.80,
        reference_weight: 15,
        auto_post_threshold: 95,
        suggestion_threshold: 85,
        rejection_window_minutes: 60
      )

      expect(config).to be_persisted
      expect(config.model_version).to eq(1)
    end

    it 'enforces unique model_version' do
      create(:confidence_adjustment, model_version: 2)

      config = ConfidenceAdjustment.new(
        model_version: 2,  # Duplicate
        amount_tolerance_pct: 2.0
      )

      expect(config).not_to be_valid
      expect(config.errors[:model_version]).to be_present
    end

    it 'returns latest configuration' do
      config1 = create(:confidence_adjustment, model_version: 1)
      config2 = create(:confidence_adjustment, model_version: 2)
      config3 = create(:confidence_adjustment, model_version: 3)

      expect(ConfidenceAdjustment.latest).to eq(config3)
    end

    it 'converts to configuration hash' do
      config = create(:confidence_adjustment,
        amount_tolerance_pct: 2.5,
        auto_post_threshold: 96
      )

      hash = config.to_configuration_hash

      expect(hash['amount_tolerance_pct']).to eq(2.5)
      expect(hash['auto_post_threshold']).to eq(96)
    end

    it 'provides defaults' do
      defaults = ConfidenceAdjustment.defaults

      expect(defaults[:amount_tolerance_pct]).to eq(2.0)
      expect(defaults[:auto_post_threshold]).to eq(95)
    end
  end

  describe 'PaymentSuggestion Model' do
    let(:transaction) { create(:bank_transaction) }

    it 'creates suggestion in pending_approval status' do
      suggestion = PaymentSuggestion.create!(
        bank_transaction: transaction,
        invoice: invoice,
        confidence_score: 89.5,
        status: 'pending_approval'
      )

      expect(suggestion).to be_persisted
      expect(suggestion.pending?).to be true
      expect(suggestion.medium_confidence?).to be true
    end

    it 'tracks approval by finance user' do
      suggestion = create(:payment_suggestion, status: 'pending_approval')

      suggestion.approve!(user)

      suggestion.reload
      expect(suggestion.approved?).to be true
      expect(suggestion.approved_by).to eq(user)
      expect(suggestion.approved_at).to be_present
    end

    it 'allows rejection' do
      suggestion = create(:payment_suggestion, status: 'pending_approval')

      suggestion.reject!

      suggestion.reload
      expect(suggestion.rejected?).to be true
    end

    it 'scopes by status' do
      pending = create(:payment_suggestion, status: 'pending_approval')
      approved = create(:payment_suggestion, status: 'approved')
      rejected = create(:payment_suggestion, status: 'rejected')

      expect(PaymentSuggestion.pending).to include(pending)
      expect(PaymentSuggestion.approve).to include(approved)
      expect(PaymentSuggestion.rejected).to include(rejected)
    end

    it 'categorizes by confidence level' do
      low = create(:payment_suggestion, confidence_score: 88.0)
      medium = create(:payment_suggestion, confidence_score: 90.0)
      high = create(:payment_suggestion, confidence_score: 98.0)

      # Note: These thresholds match service logic (85-95% = suggestion range)
      expect(low.medium_confidence?).to be true
      expect(medium.medium_confidence?).to be true
      expect(high.high_confidence?).to be true  # >95% would normally be auto-posted
    end

    it 'orders recent first' do
      suggestion1 = create(:payment_suggestion, created_at: 1.hour.ago)
      suggestion2 = create(:payment_suggestion, created_at: Time.current)

      suggestions = PaymentSuggestion.recent
      expect(suggestions.first.id).to eq(suggestion2.id)
      expect(suggestions.last.id).to eq(suggestion1.id)
    end
  end

  describe 'Payment Model Enhanced Methods' do
    let(:payment) do
      create(:payment,
        auto_posted: true,
        confidence_score: 96.5,
        rejection_window_expires_at: 1.hour.from_now,
        customer: customer
      )
    end

    it 'identifies auto_posted? correctly' do
      expect(payment.auto_posted?).to be true

      manual = create(:payment, auto_posted: false)
      expect(manual.auto_posted?).to be false
    end

    it 'identifies manual_posted? correctly' do
      expect(payment.manual_posted?).to be false

      manual = create(:payment, auto_posted: false)
      expect(manual.manual_posted?).to be true
    end

    it 'determines can_reject? based on window' do
      expect(payment.can_reject?).to be true

      expired = create(:payment,
        auto_posted: true,
        rejection_window_expires_at: 1.hour.ago
      )
      expect(expired.can_reject?).to be false

      manual = create(:payment, auto_posted: false)
      expect(manual.can_reject?).to be false
    end

    it 'calculates time_until_rejection_expires' do
      seconds_until = payment.time_until_rejection_expires
      expect(seconds_until).to be > 0
      expect(seconds_until).to be <= 3600  # 1 hour in seconds
    end

    it 'identifies reversed status' do
      expect(payment.reversed?).to be false

      reversed = create(:payment, status: 'reversed')
      expect(reversed.reversed?).to be true
    end

    it 'assigns confidence grade' do
      high = create(:payment, auto_posted: true, confidence_score: 98.0)
      expect(high.confidence_grade).to eq('high')

      medium = create(:payment, auto_posted: true, confidence_score: 90.0)
      expect(medium.confidence_grade).to eq('medium')

      low = create(:payment, auto_posted: true, confidence_score: 70.0)
      expect(low.confidence_grade).to eq('low')

      manual = create(:payment, auto_posted: false)
      expect(manual.confidence_grade).to eq('manual')
    end

    it 'scopes auto_posted payments' do
      auto = create(:payment, auto_posted: true)
      manual = create(:payment, auto_posted: false)

      expect(Payment.auto_posted).to include(auto)
      expect(Payment.auto_posted).not_to include(manual)
    end

    it 'scopes manual_posted payments' do
      auto = create(:payment, auto_posted: true)
      manual = create(:payment, auto_posted: false)

      expect(Payment.manual_posted).to include(manual)
      expect(Payment.manual_posted).not_to include(auto)
    end

    it 'scopes pending_rejection (with valid window)' do
      pending = create(:payment,
        auto_posted: true,
        rejection_window_expires_at: 1.hour.from_now
      )
      expired = create(:payment,
        auto_posted: true,
        rejection_window_expires_at: 1.hour.ago
      )

      expect(Payment.pending_rejection).to include(pending)
      expect(Payment.pending_rejection).not_to include(expired)
    end

    it 'scopes auto_posting_expired' do
      expired = create(:payment,
        auto_posted: true,
        rejection_window_expires_at: 1.hour.ago
      )
      pending = create(:payment,
        auto_posted: true,
        rejection_window_expires_at: 1.hour.from_now
      )

      expect(Payment.auto_posting_expired).to include(expired)
      expect(Payment.auto_posting_expired).not_to include(pending)
    end

    it 'associates with auto_post_audits' do
      payment
      audit = create(:auto_post_audit, payment: payment)

      payment.reload
      expect(payment.auto_post_audits).to include(audit)
    end

    it 'associates with rejection_feedbacks' do
      payment
      feedback = create(:rejection_feedback, payment: payment)

      payment.reload
      expect(payment.rejection_feedbacks).to include(feedback)
    end
  end

  describe 'Model Relationships' do
    it 'payment has many auto_post_audits' do
      payment = create(:payment, auto_posted: true)
      audit1 = create(:auto_post_audit, payment: payment)
      audit2 = create(:auto_post_audit, payment: payment)

      payment.reload
      expect(payment.auto_post_audits.count).to eq(2)
      expect(payment.auto_post_audits).to include(audit1, audit2)
    end

    it 'payment_suggestion links bank_transaction and invoice' do
      transaction = create(:bank_transaction)
      suggestion = create(:payment_suggestion,
        bank_transaction: transaction,
        invoice: invoice
      )

      expect(suggestion.bank_transaction).to eq(transaction)
      expect(suggestion.invoice).to eq(invoice)
    end

    it 'auto_post_audit links payment and bank_transaction' do
      payment = create(:payment)
      transaction = create(:bank_transaction)
      audit = create(:auto_post_audit,
        payment: payment,
        bank_transaction: transaction
      )

      expect(audit.payment).to eq(payment)
      expect(audit.bank_transaction).to eq(transaction)
    end

    it 'rejection_feedback links to payment only' do
      payment = create(:payment)
      feedback = create(:rejection_feedback, payment: payment)

      expect(feedback.payment).to eq(payment)
    end
  end
end
