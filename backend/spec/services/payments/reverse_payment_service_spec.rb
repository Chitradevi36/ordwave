require 'rails_helper'

RSpec.describe Payments::ReversePaymentService, type: :service do
  let(:org)      { create(:organization) }
  let(:branch)   { create(:branch, organization: org) }
  let(:customer) { create(:customer, organization: org) }
  let(:actor)    { create(:user) }

  let(:credit_account) do
    create(:credit_account,
           organization:    org,
           customer:        customer,
           current_balance:  0,
           available_credit: 50_000,
           credit_limit:     50_000)
  end

  def make_invoice(grand_total:, outstanding_amount: nil, status: 'issued', days_ago: 5)
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

  # Sets up a confirmed payment with allocations directly (bypassing the confirm service)
  def make_confirmed_payment_with_allocations(amount:, invoices:)
    pay = create(:payment,
                 organization:      org,
                 branch:            branch,
                 customer:          customer,
                 created_by:        actor,
                 amount:            amount,
                 status:            'confirmed',
                 allocated_amount:  amount,
                 unallocated_amount: 0,
                 confirmed_at:      Time.current)
    invoices.each do |inv, alloc_amount|
      create(:payment_allocation,
             payment:          pay,
             sales_invoice:    inv,
             allocated_amount: alloc_amount,
             status:           'active')
      inv.update_columns(
        outstanding_amount: (inv.grand_total.to_d - alloc_amount.to_d).round(2),
        paid_amount:        alloc_amount.to_f.round(2),
        status:             (inv.grand_total.to_d - alloc_amount.to_d).zero? ? 'issued' : 'partially_paid'
      )
    end
    pay
  end

  def call(payment:, reason: 'Test reversal reason')
    described_class.call(actor: actor, payment: payment, reason: reason)
  end

  before { credit_account }

  describe '.call' do
    context 'reversing a fully allocated confirmed payment' do
      let!(:inv) { make_invoice(grand_total: 1_000.0) }
      let!(:payment) do
        make_confirmed_payment_with_allocations(amount: 1_000.0, invoices: { inv => 1_000.0 })
      end

      it 'returns success' do
        expect(call(payment: payment).success?).to be true
      end

      it 'marks the payment as reversed' do
        call(payment: payment)
        expect(payment.reload.status).to eq('reversed')
      end

      it 'marks the allocation as reversed' do
        call(payment: payment)
        expect(PaymentAllocation.where(payment: payment).pluck(:status)).to all(eq('reversed'))
      end

      it 'restores the invoice outstanding_amount' do
        call(payment: payment)
        expect(inv.reload.outstanding_amount.to_f).to eq(1_000.0)
        expect(inv.reload.paid_amount.to_f).to eq(0.0)
      end

      it 'restores the invoice status to issued' do
        call(payment: payment)
        expect(inv.reload.status).to eq('issued')
      end
    end

    context 'reversing a partially allocated payment' do
      let!(:inv) { make_invoice(grand_total: 2_000.0, outstanding_amount: 1_200.0, status: 'partially_paid') }
      let!(:payment) do
        make_confirmed_payment_with_allocations(amount: 800.0, invoices: { inv => 800.0 })
      end

      it 'restores invoice to partially_paid status with correct outstanding' do
        call(payment: payment)
        expect(inv.reload.outstanding_amount.to_f).to eq(2_000.0)
        expect(inv.reload.status).to eq('issued')
      end
    end

    context 'when reversal reason is blank' do
      let!(:inv)     { make_invoice(grand_total: 500.0) }
      let!(:payment) { make_confirmed_payment_with_allocations(amount: 500.0, invoices: { inv => 500.0 }) }

      it 'returns failure' do
        result = call(payment: payment, reason: '')
        expect(result.success?).to be false
        expect(result.errors).to include('Reversal reason is required')
      end
    end

    context 'when payment is not confirmed' do
      let!(:payment) { create(:payment, organization: org, branch: branch, customer: customer, created_by: actor, status: 'draft') }

      it 'returns failure' do
        result = call(payment: payment)
        expect(result.success?).to be false
        expect(result.errors).to include('Payment is not confirmed')
      end
    end

    context 'audit logging' do
      let!(:inv)     { make_invoice(grand_total: 300.0) }
      let!(:payment) { make_confirmed_payment_with_allocations(amount: 300.0, invoices: { inv => 300.0 }) }

      it 'creates a payment_reversed audit log entry' do
        expect { call(payment: payment) }.to change(AuditLog, :count).by_at_least(1)
        expect(AuditLog.where(action: 'payment_reversed').count).to eq(1)
      end
    end

    context 'credit sync' do
      let!(:inv)     { make_invoice(grand_total: 400.0) }
      let!(:payment) { make_confirmed_payment_with_allocations(amount: 400.0, invoices: { inv => 400.0 }) }

      it 'calls CreditSyncService after reversal' do
        expect(Payments::CreditSyncService).to receive(:call).and_call_original
        call(payment: payment)
      end
    end
  end
end
