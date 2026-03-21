require 'rails_helper'

describe Payments::PaymentAutoPostService do
  let(:customer) { create(:customer) }
  let(:invoice) { create(:invoice, customer: customer, total: 10000) }
  let(:transaction) { build(:bank_transaction, amount: invoice.total) }
  let(:configuration) { ConfidenceAdjustment.latest&.to_configuration_hash }

  describe 'High Confidence Auto-Posting (≥95%)' do
    it 'creates payment with auto_posted=true' do
      service = described_class.new(
        bank_transaction: transaction,
        confidence_score: 97.5,
        matching_invoice: invoice,
        configuration: configuration
      )

      result = service.call

      expect(result.success?).to be true
      expect(result.data[:action]).to eq(:auto_posted)
      expect(result.data[:payment]).to be_persisted
      expect(result.data[:payment].auto_posted).to be true
    end

    it 'sets rejection_window_expires_at to 1 hour from now' do
      service = described_class.new(
        bank_transaction: transaction,
        confidence_score: 95.0,
        matching_invoice: invoice,
        configuration: configuration
      )

      result = service.call
      payment = result.data[:payment]

      expect(payment.rejection_window_expires_at).to be_present
      expect(payment.rejection_window_expires_at).to be > Time.current
      expect(payment.rejection_window_expires_at).to be <= 1.hour.from_now + 30.seconds
    end

    it 'updates invoice payment_received and status to paid' do
      service = described_class.new(
        bank_transaction: transaction,
        confidence_score: 98.0,
        matching_invoice: invoice,
        configuration: configuration
      )

      result = service.call

      invoice.reload
      expect(invoice.payment_received_at).to be_present
      expect(invoice.amount_paid).to eq(transaction.amount)
      expect(invoice.status).to eq('paid')
    end

    it 'creates PaymentAllocation for the invoice' do
      service = described_class.new(
        bank_transaction: transaction,
        confidence_score: 96.0,
        matching_invoice: invoice,
        configuration: configuration
      )

      result = service.call
      payment = result.data[:payment]

      allocation = PaymentAllocation.find_by(payment: payment, sales_invoice: invoice)
      expect(allocation).to be_present
      expect(allocation.allocated_amount).to eq(transaction.amount)
    end

    it 'creates AutoPostAudit entry with action=auto_posted' do
      service = described_class.new(
        bank_transaction: transaction,
        confidence_score: 97.0,
        matching_invoice: invoice,
        configuration: configuration
      )

      result = service.call
      payment = result.data[:payment]

      audit = AutoPostAudit.find_by(payment: payment)
      expect(audit).to be_present
      expect(audit.auto_posted).to be true
      expect(audit.action).to eq('auto_posted')
      expect(audit.confidence_breakdown).to be_a(Hash)
    end

    it 'schedules rejection window job' do
      service = described_class.new(
        bank_transaction: transaction,
        confidence_score: 95.5,
        matching_invoice: invoice,
        configuration: configuration
      )

      expect(RejectPaymentWindowJob).to receive(:perform_at).with(
        kind_of(ActiveSupport::TimeWithZone), anything
      )

      result = service.call
      expect(result.success?).to be true
    end

    it 'handles payment creation with correct amount' do
      amount = 15000
      transaction = build(:bank_transaction, amount: amount)
      invoice = create(:invoice, customer: customer, total: amount)

      service = described_class.new(
        bank_transaction: transaction,
        confidence_score: 96.0,
        matching_invoice: invoice,
        configuration: configuration
      )

      result = service.call
      payment = result.data[:payment]

      expect(payment.amount).to eq(amount)
      expect(payment.reference_number).to eq(transaction.reference)
    end

    it 'handles multiple auto-posts for different invoices independently' do
      invoice2 = create(:invoice, customer: customer, total: 5000)
      transaction2 = build(:bank_transaction, amount: 5000)

      service1 = described_class.new(
        bank_transaction: transaction,
        confidence_score: 97.0,
        matching_invoice: invoice,
        configuration: configuration
      )

      service2 = described_class.new(
        bank_transaction: transaction2,
        confidence_score: 96.0,
        matching_invoice: invoice2,
        configuration: configuration
      )

      result1 = service1.call
      result2 = service2.call

      expect(result1.success?).to be true
      expect(result2.success?).to be true
      expect(Payment.where(auto_posted: true).count).to eq(2)
    end
  end

  describe 'Medium Confidence Suggestions (85-94%)' do
    it 'creates PaymentSuggestion instead of Payment' do
      service = described_class.new(
        bank_transaction: transaction,
        confidence_score: 89.5,
        matching_invoice: invoice,
        configuration: configuration
      )

      result = service.call

      expect(result.success?).to be true
      expect(result.data[:action]).to eq(:suggestion_created)
      expect(result.data[:suggestion]).to be_persisted
      expect(result.data[:suggestion].status).to eq('pending_approval')
    end

    it 'does NOT create Payment record for suggestions' do
      service = described_class.new(
        bank_transaction: transaction,
        confidence_score: 87.0,
        matching_invoice: invoice,
        configuration: configuration
      )

      initial_count = Payment.count
      result = service.call

      expect(result.success?).to be true
      expect(Payment.count).to eq(initial_count)
    end

    it 'stores confidence_breakdown in suggestion' do
      service = described_class.new(
        bank_transaction: transaction,
        confidence_score: 90.0,
        matching_invoice: invoice,
        configuration: configuration
      )

      result = service.call
      suggestion = result.data[:suggestion]

      expect(suggestion.confidence_breakdown).to be_a(Hash)
      expect(suggestion.confidence_score).to eq(90.0)
    end

    it 'creates pending_approval suggestion' do
      service = described_class.new(
        bank_transaction: transaction,
        confidence_score: 85.0,
        matching_invoice: invoice,
        configuration: configuration
      )

      result = service.call
      suggestion = result.data[:suggestion]

      expect(suggestion.pending?).to be true
      expect(suggestion.approved?).to be false
      expect(suggestion.rejected?).to be false
    end
  end

  describe 'Low Confidence Manual Review (<85%)' do
    it 'routes to ManualPaymentReview queue' do
      service = described_class.new(
        bank_transaction: transaction,
        confidence_score: 75.0,
        matching_invoice: invoice,
        configuration: configuration
      )

      result = service.call

      expect(result.success?).to be true
      expect(result.data[:action]).to eq(:routed_to_manual)
      expect(result.data[:manual_item]).to be_persisted
    end

    it 'does NOT create Payment for low confidence' do
      service = described_class.new(
        bank_transaction: transaction,
        confidence_score: 80.0,
        matching_invoice: invoice,
        configuration: configuration
      )

      initial_count = Payment.count
      result = service.call

      expect(result.success?).to be true
      expect(Payment.count).to eq(initial_count)
    end

    it 'sets status=pending_review for manual item' do
      service = described_class.new(
        bank_transaction: transaction,
        confidence_score: 60.0,
        matching_invoice: invoice,
        configuration: configuration
      )

      result = service.call
      manual_item = result.data[:manual_item]

      expect(manual_item.status).to eq('pending_review')
      expect(manual_item.reason).to eq('low_confidence')
    end
  end

  describe 'Error Handling' do
    it 'returns failure when bank_transaction is missing' do
      service = described_class.new(
        bank_transaction: nil,
        confidence_score: 97.0,
        matching_invoice: invoice,
        configuration: configuration
      )

      result = service.call

      expect(result.success?).to be false
      expect(result.errors).to include("Bank transaction not found")
    end

    it 'returns failure when matching_invoice is missing' do
      service = described_class.new(
        bank_transaction: transaction,
        confidence_score: 97.0,
        matching_invoice: nil,
        configuration: configuration
      )

      result = service.call

      expect(result.success?).to be false
      expect(result.errors).to include("Matching invoice not found")
    end

    it 'returns failure when confidence_score is missing' do
      service = described_class.new(
        bank_transaction: transaction,
        confidence_score: nil,
        matching_invoice: invoice,
        configuration: configuration
      )

      result = service.call

      expect(result.success?).to be false
      expect(result.errors).to include("Confidence score not provided")
    end

    it 'handles database errors gracefully' do
      allow(Payment).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(mock))

      service = described_class.new(
        bank_transaction: transaction,
        confidence_score: 97.0,
        matching_invoice: invoice,
        configuration: configuration
      )

      result = service.call

      expect(result.success?).to be false
      expect(result.errors).to include("Failed to auto-post payment")
    end
  end

  describe 'Configuration Tests' do
    it 'respects custom auto_post_threshold' do
      custom_config = ConfidenceAdjustment.latest.to_configuration_hash || {}
      custom_config['auto_post_threshold'] = 98

      # Score 96 - should create suggestion, not auto-post
      service = described_class.new(
        bank_transaction: transaction,
        confidence_score: 96.0,
        matching_invoice: invoice,
        configuration: custom_config
      )

      result = service.call

      expect(result.success?).to be true
      expect(result.data[:action]).to eq(:suggestion_created)
    end

    it 'respects custom suggestion_threshold' do
      custom_config = ConfidenceAdjustment.latest&.to_configuration_hash || {}
      custom_config['suggestion_threshold'] = 90

      # Score 88 - should route to manual
      service = described_class.new(
        bank_transaction: transaction,
        confidence_score: 88.0,
        matching_invoice: invoice,
        configuration: custom_config
      )

      result = service.call

      expect(result.success?).to be true
      expect(result.data[:action]).to eq(:routed_to_manual)
    end
  end

  describe 'Transaction Atomicity' do
    it 'rolls back all changes on payment creation failure' do
      # Mock to fail on payment create
      allow(Payment).to receive(:create!).and_raise(StandardError.new("DB error"))

      service = described_class.new(
        bank_transaction: transaction,
        confidence_score: 97.0,
        matching_invoice: invoice,
        configuration: configuration
      )

      initial_audit_count = AutoPostAudit.count

      result = service.call

      expect(result.success?).to be false
      # Audit trail should not be created if payment fails
      expect(AutoPostAudit.count).to eq(initial_audit_count)
    end

    it 'creates invoice allocation atomically with payment' do
      service = described_class.new(
        bank_transaction: transaction,
        confidence_score: 96.0,
        matching_invoice: invoice,
        configuration: configuration
      )

      result = service.call
      payment = result.data[:payment]

      allocation = PaymentAllocation.find_by(payment: payment)
      expect(allocation).to be_present
      expect(allocation.allocated_amount).to eq(payment.amount)
    end
  end
end
