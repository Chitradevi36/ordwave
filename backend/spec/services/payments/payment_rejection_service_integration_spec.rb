require 'rails_helper'

describe Payments::PaymentRejectionService do
  let(:customer) { create(:customer) }
  let(:invoice) { create(:invoice, customer: customer, total: 10000) }
  let(:user) { create(:user, role: :finance_manager) }

  describe 'Successful Rejection Within Window' do
    it 'reverses payment status to reversed' do
      # Create auto-posted payment
      payment = create(:payment,
        auto_posted: true,
        rejection_window_expires_at: 1.hour.from_now,
        customer: customer,
        amount: 10000
      )

      service = described_class.new(
        payment: payment,
        rejection_reason: 'Customer name mismatch',
        actor: user
      )

      result = service.call

      expect(result.success?).to be true
      payment.reload
      expect(payment.status).to eq('reversed')
      expect(payment.reversed_at).to be_present
      expect(payment.reversal_reason).to eq('Customer name mismatch')
    end

    it 'sets reversed_by to the rejecting user' do
      payment = create(:payment,
        auto_posted: true,
        rejection_window_expires_at: 1.hour.from_now,
        customer: customer
      )

      service = described_class.new(
        payment: payment,
        rejection_reason: 'Wrong amount',
        actor: user
      )

      result = service.call

      payment.reload
      expect(payment.reversed_by).to eq(user)
    end

    it 'reverts invoice payment status to pending_payment' do
      payment = create(:payment,
        auto_posted: true,
        rejection_window_expires_at: 1.hour.from_now,
        customer: customer
      )

      # Create allocation to associate invoice
      allocation = create(:payment_allocation,
        payment: payment,
        sales_invoice: invoice,
        allocated_amount: payment.amount
      )

      service = described_class.new(
        payment: payment,
        rejection_reason: 'Match error',
        actor: user
      )

      result = service.call

      invoice.reload
      expect(invoice.payment_received_at).to be_nil
      expect(invoice.amount_paid).to be_zero
      expect(invoice.status).to eq('pending_payment')
    end

    it 'removes payment allocations' do
      payment = create(:payment,
        auto_posted: true,
        rejection_window_expires_at: 1.hour.from_now,
        customer: customer
      )

      allocation = create(:payment_allocation,
        payment: payment,
        sales_invoice: invoice,
        allocated_amount: payment.amount
      )

      expect(PaymentAllocation.count).to eq(1)

      service = described_class.new(
        payment: payment,
        rejection_reason: 'Correction needed',
        actor: user
      )

      result = service.call

      expect(PaymentAllocation.where(payment: payment).count).to eq(0)
    end

    it 'creates rejection audit trail' do
      payment = create(:payment,
        auto_posted: true,
        rejection_window_expires_at: 1.hour.from_now,
        customer: customer,
        confidence_score: 97.5
      )

      service = described_class.new(
        payment: payment,
        rejection_reason: 'Finance review rejected',
        actor: user
      )

      result = service.call

      audit = AutoPostAudit.find_by(payment: payment)
      expect(audit).to be_present
      expect(audit.auto_posted).to be false
      expect(audit.action).to eq('rejected_by_finance')
      expect(audit.actor_id).to eq(user.id)
      expect(audit.audit_notes).to include('rejected_by_finance')
    end

    it 'logs rejection feedback for ML learning' do
      payment = create(:payment,
        auto_posted: true,
        rejection_window_expires_at: 1.hour.from_now,
        customer: customer,
        confidence_score: 92.5
      )

      service = described_class.new(
        payment: payment,
        rejection_reason: 'Amount mismatch detected',
        actor: user
      )

      result = service.call

      feedback = RejectionFeedback.find_by(payment: payment)
      expect(feedback).to be_present
      expect(feedback.confidence_score).to eq(92.5)
      expect(feedback.rejection_reason).to eq('Amount mismatch detected')
    end

    it 'routes rejection to manual payment review' do
      payment = create(:payment,
        auto_posted: true,
        rejection_window_expires_at: 1.hour.from_now,
        customer: customer
      )

      bank_transaction = create(:bank_transaction, amount: payment.amount)
      payment.update(bank_transaction: bank_transaction)

      allocation = create(:payment_allocation,
        payment: payment,
        sales_invoice: invoice
      )

      service = described_class.new(
        payment: payment,
        rejection_reason: 'Requires manual review',
        actor: user
      )

      initial_review_count = ManualPaymentReview.count
      result = service.call

      expect(ManualPaymentReview.count).to eq(initial_review_count + 1)
      manual_review = ManualPaymentReview.where(
        bank_transaction: bank_transaction
      ).first
      expect(manual_review).to be_present
      expect(manual_review.status).to eq('pending_review')
      expect(manual_review.reason).to eq('rejected_auto_post')
    end
  end

  describe 'Rejection Window Expiration' do
    it 'returns failure if rejection window has expired' do
      payment = create(:payment,
        auto_posted: true,
        rejection_window_expires_at: 1.hour.ago,  # Expired
        customer: customer
      )

      service = described_class.new(
        payment: payment,
        rejection_reason: 'Too late',
        actor: user
      )

      result = service.call

      expect(result.success?).to be false
      expect(result.errors).to include("Rejection window has expired")
    end

    it 'returns failure if rejection_window_expires_at is nil' do
      payment = create(:payment,
        auto_posted: true,
        rejection_window_expires_at: nil,
        customer: customer
      )

      service = described_class.new(
        payment: payment,
        rejection_reason: 'No window',
        actor: user
      )

      result = service.call

      expect(result.success?).to be false
      expect(result.errors).to include("Rejection window has expired")
    end

    it 'allows rejection exactly at window boundary' do
      expiration_time = 1.hour.from_now
      payment = create(:payment,
        auto_posted: true,
        rejection_window_expires_at: expiration_time,
        customer: customer
      )

      # Mock time to be just before expiration
      allow(Time).to receive(:current).and_return(expiration_time - 1.second)

      service = described_class.new(
        payment: payment,
        rejection_reason: 'Just in time',
        actor: user
      )

      result = service.call

      # Since we mocked Time, this should succeed
      expect(result.success?).to be true
    end
  end

  describe 'Error Handling' do
    it 'returns failure when payment is not auto-posted' do
      payment = create(:payment,
        auto_posted: false,  # Manually posted
        customer: customer
      )

      service = described_class.new(
        payment: payment,
        rejection_reason: 'Cannot reject manual',
        actor: user
      )

      result = service.call

      expect(result.success?).to be false
      expect(result.errors).to include("Payment must be auto-posted to reject")
    end

    it 'returns failure when payment not found' do
      service = described_class.new(
        payment: nil,
        rejection_reason: 'Payment missing',
        actor: user
      )

      result = service.call

      expect(result.success?).to be false
      expect(result.errors).to include("Payment not found")
    end

    it 'handles database errors gracefully' do
      payment = create(:payment,
        auto_posted: true,
        rejection_window_expires_at: 1.hour.from_now,
        customer: customer
      )

      allow(payment).to receive(:update!).and_raise(StandardError.new("DB error"))

      service = described_class.new(
        payment: payment,
        rejection_reason: 'DB will fail',
        actor: user
      )

      result = service.call

      expect(result.success?).to be false
      expect(result.errors).to include("Unexpected error during rejection")
    end

    it 'handles missing invoice gracefully' do
      payment = create(:payment,
        auto_posted: true,
        rejection_window_expires_at: 1.hour.from_now,
        customer: customer
      )

      # Don't create allocation, so no invoice linked

      service = described_class.new(
        payment: payment,
        rejection_reason: 'No invoice',
        actor: user
      )

      result = service.call

      # Should still succeed, just without invoice revert
      expect(result.success?).to be true
      payment.reload
      expect(payment.reversed?).to be true
    end
  end

  describe 'Rejection Reason Handling' do
    it 'uses provided rejection_reason' do
      payment = create(:payment,
        auto_posted: true,
        rejection_window_expires_at: 1.hour.from_now,
        customer: customer
      )

      reason = 'Customer dispute on amount'

      service = described_class.new(
        payment: payment,
        rejection_reason: reason,
        actor: user
      )

      result = service.call

      payment.reload
      expect(payment.reversal_reason).to eq(reason)
    end

    it 'uses default reason if none provided' do
      payment = create(:payment,
        auto_posted: true,
        rejection_window_expires_at: 1.hour.from_now,
        customer: customer
      )

      service = described_class.new(
        payment: payment,
        rejection_reason: nil,
        actor: user
      )

      result = service.call

      payment.reload
      expect(payment.reversal_reason).to eq('Bank match rejected by finance')
    end

    it 'stores rejection reason in feedback for ML' do
      payment = create(:payment,
        auto_posted: true,
        rejection_window_expires_at: 1.hour.from_now,
        customer: customer,
        confidence_score: 88.0
      )

      specific_reason = 'Name fuzzy match was false positive'

      service = described_class.new(
        payment: payment,
        rejection_reason: specific_reason,
        actor: user
      )

      result = service.call

      feedback = RejectionFeedback.find_by(payment: payment)
      expect(feedback.rejection_reason).to eq(specific_reason)
    end
  end

  describe 'Transaction Atomicity' do
    it 'rolls back all changes on failure' do
      payment = create(:payment,
        auto_posted: true,
        rejection_window_expires_at: 1.hour.from_now,
        customer: customer,
        status: 'confirmed'
      )

      allow(AutoPostAudit).to receive(:create!).and_raise(StandardError.new("DB error"))

      service = described_class.new(
        payment: payment,
        rejection_reason: 'Will fail',
        actor: user
      )

      result = service.call

      expect(result.success?).to be false
      payment.reload
      # Payment status should not have changed
      expect(payment.status).to eq('confirmed')
      expect(payment.reversed_at).to be_nil
    end
  end

  describe 'Multi-Invoice Scenarios' do
    it 'handles payment allocated to single invoice' do
      payment = create(:payment,
        auto_posted: true,
        rejection_window_expires_at: 1.hour.from_now,
        customer: customer,
        amount: 10000
      )

      allocation = create(:payment_allocation,
        payment: payment,
        sales_invoice: invoice,
        allocated_amount: 10000
      )

      service = described_class.new(
        payment: payment,
        rejection_reason: 'Single invoice error',
        actor: user
      )

      result = service.call

      expect(result.success?).to be true
      invoice.reload
      expect(invoice.amount_paid).to be_zero
    end

    it 'handles payment with multiple allocations (reverts first)' do
      invoice2 = create(:invoice, customer: customer, total: 5000)

      payment = create(:payment,
        auto_posted: true,
        rejection_window_expires_at: 1.hour.from_now,
        customer: customer,
        amount: 10000
      )

      allocation1 = create(:payment_allocation,
        payment: payment,
        sales_invoice: invoice,
        allocated_amount: 6000
      )

      allocation2 = create(:payment_allocation,
        payment: payment,
        sales_invoice: invoice2,
        allocated_amount: 4000
      )

      service = described_class.new(
        payment: payment,
        rejection_reason: 'Multi-invoice',
        actor: user
      )

      result = service.call

      expect(result.success?).to be true
      # Revert first invoice (and allocation)
      invoice.reload
      expect(invoice.amount_paid).to be_zero
      expect(PaymentAllocation.where(payment: payment).count).to eq(0)
    end
  end

  describe 'Actor Tracking' do
    it 'tracks user who rejected payment' do
      finance_user = create(:user, name: 'John Finance', role: :finance_manager)

      payment = create(:payment,
        auto_posted: true,
        rejection_window_expires_at: 1.hour.from_now,
        customer: customer
      )

      service = described_class.new(
        payment: payment,
        rejection_reason: 'Finance review',
        actor: finance_user
      )

      result = service.call

      payment.reload
      expect(payment.reversed_by).to eq(finance_user)

      audit = AutoPostAudit.find_by(payment: payment)
      expect(audit.actor_id).to eq(finance_user.id)
    end

    it 'handles nil actor (system rejection)' do
      payment = create(:payment,
        auto_posted: true,
        rejection_window_expires_at: 1.hour.from_now,
        customer: customer
      )

      service = described_class.new(
        payment: payment,
        rejection_reason: 'System override',
        actor: nil
      )

      result = service.call

      expect(result.success?).to be true
      payment.reload
      expect(payment.reversed_by).to be_nil
    end
  end
end
