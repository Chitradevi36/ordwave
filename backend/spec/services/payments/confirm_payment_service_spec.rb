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
  end
end
