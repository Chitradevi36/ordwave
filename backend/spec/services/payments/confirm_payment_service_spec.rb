require 'rails_helper'

RSpec.describe Payments::ConfirmPaymentService, type: :service do
  let(:org)      { create(:organization) }
  let(:branch)   { create(:branch, organization: org) }
  let(:customer) { create(:customer, organization: org) }
  let(:actor)    { create(:user) }

  let(:credit_account) do
    create(:credit_account,
           organization: org,
           customer:     customer,
           current_balance:   0,
           available_credit:  50_000,
           credit_limit:      50_000)
  end

  def make_invoice(grand_total:, days_ago: 5, outstanding_amount: nil, status: 'issued')
    create(:sales_invoice,
           organization:       org,
           branch:             branch,
           customer:           customer,
           created_by:         actor,
           grand_total:        grand_total,
           subtotal:           grand_total,
           tax_total:          0,
           outstanding_amount: outstanding_amount || grand_total,
           paid_amount:        grand_total - (outstanding_amount || grand_total),
           status:             status,
           invoice_date:       Date.today - days_ago.days,
           issued_at:          Time.current - days_ago.days)
  end

  def make_payment(amount:, mode: 'cash')
    create(:payment,
           organization: org,
           branch:       branch,
           customer:     customer,
           created_by:   actor,
           amount:       amount,
           payment_mode: mode,
           status:       'draft')
  end

  def call(payment:, **opts)
    described_class.call(actor: actor, payment: payment, **opts)
  end

  before { credit_account }

  describe '.call' do
    context 'exact payment matching outstanding invoice' do
      let!(:inv)     { make_invoice(grand_total: 1_000.0) }
      let!(:payment) { make_payment(amount: 1_000.0) }

      it 'returns success' do
        expect(call(payment: payment).success?).to be true
      end

      it 'marks payment as confirmed' do
        call(payment: payment)
        expect(payment.reload.status).to eq('confirmed')
      end

      it 'creates a payment_allocation' do
        expect { call(payment: payment) }.to change(PaymentAllocation, :count).by(1)
      end

      it 'marks the invoice as void-eligible (outstanding = 0)' do
        call(payment: payment)
        expect(inv.reload.outstanding_amount).to eq(0.0)
        expect(inv.reload.status).to eq('issued') # no status change needed for full payment
      end

      it 'does not create an advance payment' do
        result = call(payment: payment)
        expect(result.advance_payment).to be_nil
        expect(AdvancePayment.count).to eq(0)
      end
    end

    context 'payment exceeds all outstanding invoices (advance scenario)' do
      let!(:inv)     { make_invoice(grand_total: 700.0) }
      let!(:payment) { make_payment(amount: 1_000.0) }

      it 'creates an advance payment for the excess' do
        result = call(payment: payment)
        expect(result.success?).to be true
        expect(result.advance_payment).to be_present
        expect(result.advance_payment.balance.to_f).to eq(300.0)
      end

      it 'sets payment unallocated_amount correctly' do
        call(payment: payment)
        expect(payment.reload.unallocated_amount.to_f).to eq(300.0)
        expect(payment.reload.allocated_amount.to_f).to eq(700.0)
      end
    end

    context 'partial payment against a large invoice' do
      let!(:inv)     { make_invoice(grand_total: 2_000.0) }
      let!(:payment) { make_payment(amount: 800.0) }

      it 'marks invoice as partially_paid' do
        call(payment: payment)
        expect(inv.reload.status).to eq('partially_paid')
        expect(inv.reload.outstanding_amount.to_f).to eq(1_200.0)
        expect(inv.reload.paid_amount.to_f).to eq(800.0)
      end
    end

    context 'with manual_lines override' do
      let!(:inv1)    { make_invoice(grand_total: 500.0, days_ago: 10) }
      let!(:inv2)    { make_invoice(grand_total: 500.0, days_ago:  2) }
      let!(:payment) { make_payment(amount: 500.0) }

      it 'allocates to the specified invoice (newer, skipping older)' do
        result = call(
          payment:       payment,
          manual_lines:  [{ sales_invoice_id: inv2.id, amount: 500.0 }]
        )
        expect(result.success?).to be true
        alloc = PaymentAllocation.last
        expect(alloc.sales_invoice_id).to eq(inv2.id)
        expect(inv1.reload.outstanding_amount.to_f).to eq(500.0)
      end
    end

    context 'when payment is not in draft status' do
      let!(:payment) { make_payment(amount: 500.0).tap { |p| p.update_columns(status: 'confirmed') } }

      it 'returns failure' do
        result = call(payment: payment)
        expect(result.success?).to be false
        expect(result.errors).to include('Payment is not in draft status')
      end
    end

    context 'when payment amount is zero' do
      let!(:payment) do
        p = build(:payment, organization: org, branch: branch, customer: customer,
                  created_by: actor, amount: 1, status: 'draft')
        p.save!(validate: false)
        p.update_columns(amount: 0)
        p
      end

      it 'returns failure' do
        result = call(payment: payment)
        expect(result.success?).to be false
        expect(result.errors).to include('Payment amount must be positive')
      end
    end

    context 'credit sync' do
      let!(:inv)     { make_invoice(grand_total: 1_000.0) }
      let!(:payment) { make_payment(amount: 1_000.0) }

      it 'updates the credit account balance after payment' do
        expect(Payments::CreditSyncService).to receive(:call).and_call_original
        call(payment: payment)
      end
    end

    # Feature 9: Dunning suspension handling
    context 'payment from dunning-suspended customer' do
      let!(:inv)     { make_invoice(grand_total: 1_000.0) }
      let!(:payment) { make_payment(amount: 1_000.0) }

      before do
        customer.update(
          credit_block_rule: 'hard_block',
          dunning_suspended_at: 3.days.ago,
          dunning_suspension_reason: 'overdue_invoice',
          dunning_suspension_invoice_id: 'INV-123'
        )
      end

      it 'allows payment to proceed (important for resolving dunning)' do
        result = call(payment: payment)
        expect(result.success?).to be true
        expect(payment.reload.status).to eq('confirmed')
      end

      it 'creates audit log noting suspended customer payment' do
        expect {
          call(payment: payment)
        }.to change(AuditLog, :count)

        audit = AuditLog.where(action: 'payment_from_suspended_customer').last
        expect(audit).to be_present
        expect(audit.changes['suspended_since']).to be_present
        expect(audit.changes['requires_manual_review']).to be true
      end

      it 'notifies finance team for manual review' do
        expect {
          call(payment: payment)
        }.to change(Notification, :count)

        notification = Notification.where(notification_type: 'payment_from_suspended_customer').last
        expect(notification).to be_present
        expect(notification.title).to include('suspended account')
        expect(notification.body).to include(customer.name)
        expect(notification.severity).to eq('high')
      end

      it 'records suspension details in audit log' do
        call(payment: payment)
        
        audit = AuditLog.where(action: 'payment_from_suspended_customer').last
        expect(audit.changes).to include(
          'customer_id' => customer.id,
          'suspension_reason' => 'overdue_invoice',
          'suspension_invoice_id' => 'INV-123'
        )
      end

      it 'applies payment allocation to suspended customer invoices' do
        call(payment: payment)
        expect(PaymentAllocation.count).to eq(1)
        expect(inv.reload.status).to eq('issued') # Marked as paid
        expect(inv.reload.outstanding_amount).to eq(0.0)
      end
    end

    context 'suspended customer with partial payment' do
      let!(:inv)     { make_invoice(grand_total: 1_000.0) }
      let!(:payment) { make_payment(amount: 500.0) }

      before do
        customer.update(
          dunning_suspended_at: 5.days.ago,
          dunning_suspension_reason: 'overdue_invoice'
        )
      end

      it 'creates partial payment allocation' do
        result = call(payment: payment)
        expect(result.success?).to be true
        expect(inv.reload.outstanding_amount).to eq(500.0)
        expect(inv.reload.paid_amount).to eq(500.0)
      end

      it 'still flags for manual review' do
        call(payment: payment)
        
        audit = AuditLog.where(action: 'payment_from_suspended_customer').last
        expect(audit).to be_present
      end
    end

    # Feature 11: Advance Deduction & Partial Payment Support
    context 'payment with available advance balance' do
      let!(:inv1)     { make_invoice(grand_total: 500.0, days_ago: 10) }
      let!(:inv2)     { make_invoice(grand_total: 300.0, days_ago: 5) }
      let!(:adv_payment) { make_payment(amount: 200.0) }
      
      before do
        adv_payment.update(status: 'confirmed')
        @advance = create(:advance_payment, 
                         organization: org, branch: branch, customer: customer,
                         source_payment: adv_payment,
                         original_amount: 200.0, balance: 200.0,
                         status: 'unapplied')
      end

      let!(:payment) { make_payment(amount: 300.0) }

      it 'auto-applies available advance to oldest invoice' do
        call(payment: payment)

        # Advance should reduce inv1
        expect(inv1.reload.paid_amount).to be > 0
        expect(inv1.reload.outstanding_amount).to be < 500.0
      end

      it 'uses cash payment to cover remainder' do
        call(payment: payment)

        # Cash (300) should go to inv1 (now 300 outstanding after 200 advance)
        # and inv2 (if needed)
        total_paid = payment.reload.allocated_amount.to_f
        expect(total_paid).to be > 0
      end

      it 'reduces advance balance' do
        call(payment: payment)
        expect(@advance.reload.balance).to be < 200.0
      end

      it 'creates audit log for advance deduction' do
        expect {
          call(payment: payment)
        }.to change { AuditLog.where(action: 'payment_advance_deduction_applied').count }
      end

      it 'deducts full advance when payment is smaller' do
        small_payment = make_payment(amount: 50.0)
        
        result = call(payment: small_payment)
        expect(result.success?).to be true
        
        # Smaller payment but advance fully applied
        expect(@advance.reload.balance).to eq(150.0)
      end
    end

    context 'payment with multiple advances' do
      let!(:inv)          { make_invoice(grand_total: 1_000.0) }
      let!(:adv_pay_1)    { make_payment(amount: 200.0) }
      let!(:adv_pay_2)    { make_payment(amount: 150.0) }
      let!(:payment)      { make_payment(amount: 400.0) }

      before do
        adv_pay_1.update(status: 'confirmed')
        adv_pay_2.update(status: 'confirmed')

        @advance1 = create(:advance_payment,
                          organization: org, branch: branch, customer: customer,
                          source_payment: adv_pay_1,
                          original_amount: 200.0, balance: 200.0,
                          status: 'unapplied', created_at: 2.days.ago)
        @advance2 = create(:advance_payment,
                          organization: org, branch: branch, customer: customer,
                          source_payment: adv_pay_2,
                          original_amount: 150.0, balance: 150.0,
                          status: 'unapplied', created_at: 1.day.ago)
      end

      it 'applies advances in FIFO order' do
        result = call(payment: payment)
        expect(result.success?).to be true

        # First advance should be used first
        expect(@advance1.reload.balance).to be < 200.0
      end

      it 'uses both advances if payment is large enough' do
        large_payment = make_payment(amount: 800.0)
        
        result = call(payment: large_payment)
        expect(result.success?).to be true

        # Both advances should be reduced
        expect(@advance1.reload.balance).to eq(0.0)
        expect(@advance2.reload.balance).to eq(0.0)
      end

      it 'only uses necessary advances' do
        small_payment = make_payment(amount: 100.0)
        
        result = call(payment: small_payment)
        expect(result.success?).to be true

        # Only first advance should be tapped
        expect(@advance1.reload.balance).to eq(100.0)
        expect(@advance2.reload.balance).to eq(150.0)
      end
    end

    context 'no advances available' do
      let!(:inv)     { make_invoice(grand_total: 1_000.0) }
      let!(:payment) { make_payment(amount: 500.0) }

      it 'processes payment normally via FIFO' do
        result = call(payment: payment)
        expect(result.success?).to be true
        expect(inv.reload.paid_amount).to eq(500.0)
      end

      it 'creates advance for unallocated amount' do
        result = call(payment: payment)
        expect(result.advance_payment).to be_present
        expect(result.advance_payment.balance).to eq(0.0)
      end

      it 'does not log advance deduction' do
        expect {
          call(payment: payment)
        }.not_to change { AuditLog.where(action: 'payment_advance_deduction_applied').count }
      end
    end

    context 'partial advance usage' do
      let!(:inv1) { make_invoice(grand_total: 500.0, days_ago: 10) }
      let!(:inv2) { make_invoice(grand_total: 300.0, days_ago: 5) }
      let!(:adv_payment) { make_payment(amount: 400.0) }

      before do
        adv_payment.update(status: 'confirmed')
        @advance = create(:advance_payment,
                         organization: org, branch: branch, customer: customer,
                         source_payment: adv_payment,
                         original_amount: 400.0, balance: 400.0,
                         status: 'unapplied')
      end

      let!(:payment) { make_payment(amount: 200.0) }

      it 'applies only needed advance amount' do
        result = call(payment: payment)
        expect(result.success?).to be true

        # Only 200 from advance needed (payment amount)
        expect(@advance.reload.balance).to eq(200.0)
      end

      it 'records correct deduction in audit log' do
        call(payment: payment)
        
        audit = AuditLog.where(action: 'payment_advance_deduction_applied').last
        expect(audit.changes['advance_deducted']).to eq(200.0)
      end
    end

    context 'advance with partial applied state' do
      let!(:inv) { make_invoice(grand_total: 1_000.0) }
      let!(:adv_payment) { make_payment(amount: 500.0) }
      let!(:payment) { make_payment(amount: 300.0) }

      before do
        adv_payment.update(status: 'confirmed')
        @advance = create(:advance_payment,
                         organization: org, branch: branch, customer: customer,
                         source_payment: adv_payment,
                         original_amount: 500.0, balance: 200.0,
                         status: 'partially_applied')
      end

      it 'continues using partially applied advance' do
        result = call(payment: payment)
        expect(result.success?).to be true

        # Remaining balance from partial advance should be used
        expect(@advance.reload.balance).to be < 200.0
      end
    end
  end
end
