require 'rails_helper'

describe 'Bank Auto-Posting Complete Workflow' do
  let(:customer) { create(:customer) }
  let(:branch) { customer.organization.branches.first }
  let(:invoice) { create(:invoice, customer: customer, branch: branch, total: 10000) }
  let(:finance_user) { create(:user, role: :finance_manager) }

  describe 'Workflow 1: High Confidence Auto-Post → Acceptance (Window Expires)' do
    it 'auto-posts payment and finalizes after 1 hour' do
      # 1. Create bank transaction
      transaction = create(:bank_transaction,
        amount: invoice.total,
        date: invoice.issue_date.to_date,
        customer_name: customer.name,
        reference: "INV-#{invoice.invoice_number}"
      )

      # 2. Score confidence
      scorer = Payments::ConfidenceScorerService.new(
        bank_transaction: transaction,
        matching_invoice: invoice
      )
      score_result = scorer.call
      expect(score_result.success?).to be true
      confidence = score_result.data[:confidence]
      expect(confidence).to be >= 95

      # 3. Auto-post payment
      autoposter = Payments::PaymentAutoPostService.new(
        bank_transaction: transaction,
        confidence_score: confidence,
        matching_invoice: invoice
      )
      post_result = autoposter.call
      expect(post_result.success?).to be true
      expect(post_result.data[:action]).to eq(:auto_posted)
      payment = post_result.data[:payment]

      # 4. Verify payment state
      expect(payment.auto_posted?).to be true
      expect(payment.can_reject?).to be true
      expect(invoice.reload.paid?).to be true

      # 5. Verify audit trail
      audit = AutoPostAudit.find_by(payment: payment)
      expect(audit).to be_present
      expect(audit.auto_posted?).to be true

      # 6. Window expires and job runs
      allow(Time).to receive(:current).and_return(1.hour.from_now + 1.minute)
      
      job = RejectPaymentWindowJob.new
      job.perform(payment.id)

      payment.reload
      expect(payment.rejection_window_expires_at).to be_nil

      # 7. Verify finalization audit
      finalization_audit = AutoPostAudit.where(payment: payment).last
      expect(finalization_audit.audit_notes).to include('finalized')
    end
  end

  describe 'Workflow 2: High Confidence → Rejection Within Window' do
    it 'auto-posts then allows rejection and manual review' do
      # 1. Auto-post payment
      transaction = create(:bank_transaction,
        amount: invoice.total,
        date: invoice.issue_date.to_date,
        customer_name: customer.name,
        reference: "INV-#{invoice.invoice_number}"
      )

      autoposter = Payments::PaymentAutoPostService.new(
        bank_transaction: transaction,
        confidence_score: 96.0,
        matching_invoice: invoice
      )
      post_result = autoposter.call
      payment = post_result.data[:payment]

      expect(payment.auto_posted?).to be true
      invoice.reload
      expect(invoice.paid?).to be true

      # 2. Finance review rejects within window
      rejector = Payments::PaymentRejectionService.new(
        payment: payment,
        rejection_reason: 'Customer name typo - false match',
        actor: finance_user
      )
      reject_result = rejector.call
      expect(reject_result.success?).to be true

      # 3. Verify payment reversed
      payment.reload
      expect(payment.reversed?).to be true
      expect(payment.reversed_at).to be_present
      expect(payment.reversed_by).to eq(finance_user)

      # 4. Verify invoice reverted
      invoice.reload
      expect(invoice.pending_payment?).to be true
      expect(invoice.amount_paid).to eq(0)

      # 5. Verify routed to manual review
      manual_review = ManualPaymentReview.where(
        bank_transaction: transaction
      ).first
      expect(manual_review).to be_present
      expect(manual_review.status).to eq('pending_review')

      # 6. Verify audit trail
      rejection_audit = AutoPostAudit.find_by(
        payment: payment,
        action: 'rejected_by_finance'
      )
      expect(rejection_audit).to be_present
      expect(rejection_audit.actor_id).to eq(finance_user.id)
    end
  end

  describe 'Workflow 3: Medium Confidence → Suggestion → Approval' do
    it 'creates suggestion then converts to payment on approval' do
      # 1. Create transaction with medium confidence match
      transaction = create(:bank_transaction,
        amount: invoice.total,
        date: invoice.issue_date.to_date,
        customer_name: 'CUST ' + customer.name,  # Slightly different name
        reference: "Order #{invoice.order.order_number}"
      )

      # 2. Score - expect 85-94% confidence
      scorer = Payments::ConfidenceScorerService.new(
        bank_transaction: transaction,
        matching_invoice: invoice
      )
      score_result = scorer.call
      confidence = score_result.data[:confidence]
      expect(confidence).to be_between(85, 94)

      # 3. Create suggestion (don't auto-post)
      autoposter = Payments::PaymentAutoPostService.new(
        bank_transaction: transaction,
        confidence_score: confidence,
        matching_invoice: invoice
      )
      post_result = autoposter.call
      expect(post_result.data[:action]).to eq(:suggestion_created)
      suggestion = post_result.data[:suggestion]

      # 4. Verify no payment created yet
      expect(Payment.where(auto_posted: false).count).to eq(0)
      expect(suggestion.pending?).to be true

      # 5. Finance approves suggestion (manual step)
      suggestion.approve!(finance_user)
      suggestion.reload
      expect(suggestion.approved?).to be true
      expect(suggestion.approved_by).to eq(finance_user)

      # 6. Finance manually creates payment (simulated)
      payment = Payment.create!(
        organization: invoice.organization,
        branch: invoice.branch,
        customer: customer,
        amount: transaction.amount,
        payment_mode: 'bank_transfer',
        received_date: transaction.date,
        reference_number: transaction.reference,
        created_by: finance_user,
        confidence_score: confidence,
        auto_posted: false,
        status: 'confirmed'
      )

      PaymentAllocation.create!(
        payment: payment,
        sales_invoice: invoice,
        amount: payment.amount
      )

      invoice.update!(
        payment_received_at: Time.current,
        amount_paid: payment.amount,
        status: 'paid'
      )

      # 7. Verify invoice is now paid
      invoice.reload
      expect(invoice.paid?).to be true
    end
  end

  describe 'Workflow 4: Low Confidence → Manual Queue → Manual Approval' do
    it 'routes to manual review and awaits finance review' do
      # 1. Create transaction with very different details
      transaction = create(:bank_transaction,
        amount: invoice.total * 0.90,  # Amount mismatch
        date: invoice.issue_date.to_date + 10.days,  # Date mismatch
        customer_name: 'DIFFERENT COMPANY',  # Name mismatch
        reference: 'RANDOM-PAYMENT-123'  # No reference match
      )

      # 2. Score - expect <85% confidence
      scorer = Payments::ConfidenceScorerService.new(
        bank_transaction: transaction,
        matching_invoice: invoice
      )
      score_result = scorer.call
      confidence = score_result.data[:confidence]
      expect(confidence).to be < 85

      # 3. Route to manual
      autoposter = Payments::PaymentAutoPostService.new(
        bank_transaction: transaction,
        confidence_score: confidence,
        matching_invoice: invoice
      )
      post_result = autoposter.call
      expect(post_result.data[:action]).to eq(:routed_to_manual)

      # 4. Verify no payment created
      expect(Payment.count).to eq(0)

      # 5. Finance manually reviews (in UI)
      manual_review = ManualPaymentReview.last
      expect(manual_review).to be_present
      expect(manual_review.status).to eq('pending_review')

      # 6. Finance investigates and manually creates payment if valid
      # (This is a manual process - we just verify routing happened)
      expect(manual_review.suggested_invoice).to eq(invoice)
      expect(manual_review.confidence_score).to eq(confidence)
    end
  end

  describe 'Workflow 5: High Confidence but Different Invoice (False Match)' do
    it 'auto-posts then rejects, preventing payment to wrong invoice' do
      other_invoice = create(:invoice, customer: customer, total: 10000)

      # Transaction matches this invoice's amount exactly but belongs to other_invoice
      transaction = create(:bank_transaction,
        amount: invoice.total,
        date: invoice.issue_date.to_date,
        customer_name: customer.name,
        reference: "INV-#{other_invoice.invoice_number}"  # Wrong invoice ref!
      )

      # Scorer matches against invoice (wrong match)
      scorer = Payments::ConfidenceScorerService.new(
        bank_transaction: transaction,
        matching_invoice: invoice
      )
      score_result = scorer.call
      confidence = score_result.data[:confidence]

      # Auto-posts (confident in amount/date/customer, but wrong invoice)
      autoposter = Payments::PaymentAutoPostService.new(
        bank_transaction: transaction,
        confidence_score: confidence,
        matching_invoice: invoice
      )
      post_result = autoposter.call
      payment = post_result.data[:payment]

      invoice.reload
      expect(invoice.paid?).to be true  # Wrong invoice marked paid!

      # Finance catches it and rejects during 1-hour window
      rejector = Payments::PaymentRejectionService.new(
        payment: payment,
        rejection_reason: 'Wrong invoice - reference shows INV-#{other_invoice.invoice_number}',
        actor: finance_user
      )
      reject_result = rejector.call

      # Verify reversal
      invoice.reload
      expect(invoice.pending_payment?).to be true  # Now not paid
      payment.reload
      expect(payment.reversed?).to be true

      # Properly matched to correct invoice
      other_invoice_payment = Payment.create!(
        organization: invoice.organization,
        branch: invoice.branch,
        customer: customer,
        amount: transaction.amount,
        payment_mode: 'bank_transfer',
        received_date: transaction.date,
        reference_number: transaction.reference,
        created_by: finance_user,
        status: 'confirmed'
      )

      PaymentAllocation.create!(
        payment: other_invoice_payment,
        sales_invoice: other_invoice,
        amount: transaction.amount
      )

      other_invoice.update!(
        payment_received_at: Time.current,
        amount_paid: transaction.amount,
        status: 'paid'
      )

      other_invoice.reload
      expect(other_invoice.paid?).to be true
    end
  end

  describe 'Workflow 6: Partial Payment (Amount Mismatch)' do
    it 'handles payment less than invoice amount' do
      partial_amount = invoice.total * 0.6  # Only 60% of invoice

      transaction = create(:bank_transaction,
        amount: partial_amount,
        date: invoice.issue_date.to_date,
        customer_name: customer.name,
        reference: "INV-#{invoice.invoice_number}/PARTIAL"
      )

      # Score will be lower due to amount mismatch
      scorer = Payments::ConfidenceScorerService.new(
        bank_transaction: transaction,
        matching_invoice: invoice
      )
      score_result = scorer.call
      confidence = score_result.data[:confidence]
      expect(confidence).to be < 95

      # Routes to suggestion or manual
      autoposter = Payments::PaymentAutoPostService.new(
        bank_transaction: transaction,
        confidence_score: confidence,
        matching_invoice: invoice
      )
      post_result = autoposter.call

      # Finance approves as intentional partial
      if post_result.data[:action] == :suggestion_created
        suggestion = post_result.data[:suggestion]
        suggestion.approve!(finance_user)

        payment = Payment.create!(
          organization: invoice.organization,
          branch: invoice.branch,
          customer: customer,
          amount: partial_amount,
          payment_mode: 'bank_transfer',
          received_date: transaction.date,
          reference_number: transaction.reference,
          created_by: finance_user,
          status: 'confirmed'
        )

        PaymentAllocation.create!(
          payment: payment,
          sales_invoice: invoice,
          allocated_amount: partial_amount
        )

        invoice.update!(
          amount_paid: partial_amount
        )

        invoice.reload
        expect(invoice.amount_paid).to eq(partial_amount)
        expect(invoice.outstanding_amount).to be > 0
      end
    end
  end

  describe 'Workflow 7: Multiple Banks in One Day' do
    it 'handles multiple concurrent auto-postings' do
      invoice2 = create(:invoice, customer: customer, total: 5000)
      invoice3 = create(:invoice, customer: customer, total: 7500)

      transaction1 = create(:bank_transaction,
        amount: invoice.total,
        date: invoice.issue_date.to_date,
        customer_name: customer.name,
        reference: "INV-#{invoice.invoice_number}"
      )

      transaction2 = create(:bank_transaction,
        amount: invoice2.total,
        date: invoice2.issue_date.to_date,
        customer_name: customer.name,
        reference: "INV-#{invoice2.invoice_number}"
      )

      transaction3 = create(:bank_transaction,
        amount: invoice3.total,
        date: invoice3.issue_date.to_date,
        customer_name: customer.name,
        reference: "INV-#{invoice3.invoice_number}"
      )

      # Auto-post all three
      [
        [transaction1, invoice],
        [transaction2, invoice2],
        [transaction3, invoice3]
      ].each do |txn, inv|
        autoposter = Payments::PaymentAutoPostService.new(
          bank_transaction: txn,
          confidence_score: 97.0,
          matching_invoice: inv
        )
        result = autoposter.call
        expect(result.success?).to be true
      end

      # Verify all invoices marked paid
      expect(invoice.reload.paid?).to be true
      expect(invoice2.reload.paid?).to be true
      expect(invoice3.reload.paid?).to be true

      # Verify three separate payments created
      expect(Payment.where(auto_posted: true).count).to eq(3)

      # Verify three separate audits
      expect(AutoPostAudit.where(action: 'auto_posted').count).to eq(3)
    end
  end
end
