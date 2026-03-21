require 'rails_helper'

RSpec.describe Payments::AdvanceAllocationService, type: :service do
  let(:org)      { create(:organization) }
  let(:branch)   { create(:branch, organization: org) }
  let(:customer) { create(:customer, organization: org, branch: branch) }
  let(:actor)    { create(:user) }

  let(:credit_account) do
    create(:credit_account,
           organization: org,
           customer:     customer,
           current_balance:   0,
           available_credit:  50_000,
           credit_limit:      50_000)
  end

  before { credit_account }

  def make_invoice(grand_total:, days_ago: 5, status: 'issued')
    create(:sales_invoice,
           organization:       org,
           branch:             branch,
           customer:           customer,
           created_by:         actor,
           grand_total:        grand_total,
           subtotal:           grand_total,
           tax_total:          0,
           outstanding_amount: grand_total,
           paid_amount:        0,
           status:             status,
           invoice_date:       Date.today - days_ago.days,
           issued_at:          Time.current - days_ago.days)
  end

  describe '.call' do
    context 'basic advance allocation to single invoice' do
      before do
        @inv = make_invoice(grand_total: 1_000)
        @payment = create(:payment, organization: org, branch: branch, customer: customer,
                         amount: 500, status: 'draft')
        @advance = create(:advance_payment, organization: org, branch: branch, customer: customer,
                         source_payment: @payment, original_amount: 500, balance: 500,
                         status: 'unapplied')
      end

      it 'allocates advance to invoice' do
        result = described_class.call(
          actor:            actor,
          customer:         customer,
          deduction_amount: 200.0,
          advance_payment:  @advance
        )

        expect(result.success?).to be true
        expect(result.allocations.count).to eq(1)
        expect(@inv.reload.outstanding_amount).to eq(800.0)
        expect(@inv.reload.paid_amount).to eq(200.0)
      end

      it 'updates advance balance' do
        result = described_class.call(
          actor:            actor,
          customer:         customer,
          deduction_amount: 200.0,
          advance_payment:  @advance
        )

        expect(@advance.reload.balance).to eq(300.0)
      end

      it 'updates source payment allocated/unallocated amounts' do
        result = described_class.call(
          actor:            actor,
          customer:         customer,
          deduction_amount: 200.0,
          advance_payment:  @advance
        )

        @payment.reload
        expect(@payment.allocated_amount).to eq(200.0)
        expect(@payment.unallocated_amount).to eq(300.0)
      end

      it 'creates audit log' do
        expect {
          described_class.call(
            actor:            actor,
            customer:         customer,
            deduction_amount: 200.0,
            advance_payment:  @advance
          )
        }.to change { AuditLog.where(action: 'advance_auto_applied_to_invoice').count }.by(1)
      end

      it 'syncs credit account' do
        expect(Payments::CreditSyncService).to receive(:call).and_call_original
        described_class.call(
          actor:            actor,
          customer:         customer,
          deduction_amount: 200.0,
          advance_payment:  @advance
        )
      end
    end

    context 'allocation across multiple invoices (oldest first)' do
      before do
        @inv1 = make_invoice(grand_total: 500, days_ago: 10)  # Oldest
        @inv2 = make_invoice(grand_total: 300, days_ago: 5)   # Newer
        @payment = create(:payment, organization: org, branch: branch, customer: customer, amount: 600)
        @advance = create(:advance_payment, organization: org, branch: branch, customer: customer,
                         source_payment: @payment, original_amount: 600, balance: 600,
                         status: 'unapplied')
      end

      it 'applies to oldest invoice first' do
        result = described_class.call(
          actor:            actor,
          customer:         customer,
          deduction_amount: 600.0,
          advance_payment:  @advance
        )

        expect(result.success?).to be true
        expect(result.allocations.count).to eq(2)

        # Oldest invoice fully paid
        expect(@inv1.reload.outstanding_amount).to eq(0.0)
        expect(@inv1.reload.paid_amount).to eq(500.0)

        # Remaining goes to newer invoice
        expect(@inv2.reload.outstanding_amount).to eq(0.0)
        expect(@inv2.reload.paid_amount).to eq(300.0)
      end

      it 'applies exact amounts to each invoice' do
        result = described_class.call(
          actor:            actor,
          customer:         customer,
          deduction_amount: 550.0,  # Partial across both
          advance_payment:  @advance
        )

        expect(@inv1.reload.outstanding_amount).to eq(0.0)
        expect(@inv2.reload.outstanding_amount).to eq(250.0) # 300 - 50
      end

      it 'updates advance balance correctly' do
        result = described_class.call(
          actor:            actor,
          customer:         customer,
          deduction_amount: 600.0,
          advance_payment:  @advance
        )

        expect(@advance.reload.balance).to eq(0.0)
        expect(@advance.reload.status).to eq('applied')
      end

      it 'allocates to partially paid invoices' do
        # Make first invoice partially paid
        @inv1.update(paid_amount: 200, outstanding_amount: 300)

        result = described_class.call(
          actor:            actor,
          customer:         customer,
          deduction_amount: 400.0,
          advance_payment:  @advance
        )

        expect(@inv1.reload.outstanding_amount).to eq(0.0)
        expect(@inv1.reload.paid_amount).to eq(500.0)
        expect(@inv2.reload.outstanding_amount).to eq(200.0) # 300 - 100
      end
    end

    context 'partial deduction' do
      before do
        @inv1 = make_invoice(grand_total: 500, days_ago: 10)
        @inv2 = make_invoice(grand_total: 300, days_ago: 5)
        @payment = create(:payment, organization: org, branch: branch, customer: customer, amount: 1000)
        @advance = create(:advance_payment, organization: org, branch: branch, customer: customer,
                         source_payment: @payment, original_amount: 1000, balance: 1000,
                         status: 'unapplied')
      end

      it 'allocates only deduction amount, leaving remainder' do
        result = described_class.call(
          actor:            actor,
          customer:         customer,
          deduction_amount: 300.0,
          advance_payment:  @advance
        )

        expect(@inv1.reload.outstanding_amount).to eq(200.0) # 500 - 300
        expect(@inv2.reload.outstanding_amount).to eq(300.0) # Unchanged
        expect(@advance.reload.balance).to eq(700.0)
      end

      it 'handles deduction smaller than single invoice' do
        result = described_class.call(
          actor:            actor,
          customer:         customer,
          deduction_amount: 100.0,
          advance_payment:  @advance
        )

        expect(result.allocations.count).to eq(1)
        expect(@inv1.reload.outstanding_amount).to eq(400.0)
        expect(@inv2.reload.outstanding_amount).to eq(300.0)
      end
    end

    context 'error cases' do
      before do
        @inv = make_invoice(grand_total: 1_000)
        @payment = create(:payment, organization: org, branch: branch, customer: customer, amount: 500)
        @advance = create(:advance_payment, organization: org, branch: branch, customer: customer,
                         source_payment: @payment, original_amount: 500, balance: 500,
                         status: 'unapplied')
      end

      it 'fails when advance is nil' do
        result = described_class.call(
          actor:            actor,
          customer:         customer,
          deduction_amount: 100.0,
          advance_payment:  nil
        )

        expect(result.success?).to be false
        expect(result.errors).to include('Advance payment not found')
      end

      it 'fails when deduction amount is negative' do
        result = described_class.call(
          actor:            actor,
          customer:         customer,
          deduction_amount: -100.0,
          advance_payment:  @advance
        )

        expect(result.success?).to be false
        expect(result.errors).to include('Amount must be positive')
      end

      it 'fails when deduction exceeds advance balance' do
        result = described_class.call(
          actor:            actor,
          customer:         customer,
          deduction_amount: 600.0,  # More than 500 balance
          advance_payment:  @advance
        )

        expect(result.success?).to be false
        expect(result.errors).to include('Amount exceeds advance balance')
      end
    end

    context 'invoice status handling' do
      before do
        @payment = create(:payment, organization: org, branch: branch, customer: customer, amount: 500)
        @advance = create(:advance_payment, organization: org, branch: branch, customer: customer,
                         source_payment: @payment, original_amount: 500, balance: 500,
                         status: 'unapplied')
      end

      it 'updates invoice status to paid when fully paid' do
        @inv = make_invoice(grand_total: 200, status: 'issued')

        result = described_class.call(
          actor:            actor,
          customer:         customer,
          deduction_amount: 200.0,
          advance_payment:  @advance
        )

        expect(@inv.reload.status).to eq('paid')
      end

      it 'updates invoice status to partially_paid when partially paid' do
        @inv = make_invoice(grand_total: 500, status: 'issued')

        result = described_class.call(
          actor:            actor,
          customer:         customer,
          deduction_amount: 200.0,
          advance_payment:  @advance
        )

        expect(@inv.reload.status).to eq('partially_paid')
      end

      it 'skips paid invoices' do
        @inv = make_invoice(grand_total: 500, status: 'paid')
        @inv.update(outstanding_amount: 0, paid_amount: 500)

        result = described_class.call(
          actor:            actor,
          customer:         customer,
          deduction_amount: 200.0,
          advance_payment:  @advance
        )

        # Allocation should skip this invoice
        expect(result.allocations.count).to eq(0)
        expect(@advance.reload.balance).to eq(500.0)
      end
    end

    context 'advance status synchronization' do
      before do
        @payment = create(:payment, organization: org, branch: branch, customer: customer, amount: 500)
        @advance = create(:advance_payment, organization: org, branch: branch, customer: customer,
                         source_payment: @payment, original_amount: 500, balance: 500,
                         status: 'unapplied')
      end

      it 'syncs to partially_applied when partial deduction' do
        @inv = make_invoice(grand_total: 1_000)

        described_class.call(
          actor:            actor,
          customer:         customer,
          deduction_amount: 200.0,
          advance_payment:  @advance
        )

        expect(@advance.reload.status).to eq('partially_applied')
      end

      it 'syncs to applied when fully deducted' do
        @inv = make_invoice(grand_total: 1_000)

        described_class.call(
          actor:            actor,
          customer:         customer,
          deduction_amount: 500.0,
          advance_payment:  @advance
        )

        expect(@advance.reload.status).to eq('applied')
      end
    end

    context 'integration with multiple payment allocations' do
      before do
        @inv1 = make_invoice(grand_total: 500, days_ago: 10)
        @inv2 = make_invoice(grand_total: 300, days_ago: 5)
        @payment = create(:payment, organization: org, branch: branch, customer: customer, amount: 1000)
        @advance = create(:advance_payment, organization: org, branch: branch, customer: customer,
                         source_payment: @payment, original_amount: 1000, balance: 1000,
                         status: 'unapplied')
      end

      it 'creates allocations linked to advance source payment' do
        result = described_class.call(
          actor:            actor,
          customer:         customer,
          deduction_amount: 600.0,
          advance_payment:  @advance
        )

        allocations = PaymentAllocation.where(payment: @payment)
        expect(allocations.count).to eq(2)
        expect(allocations.pluck(:allocated_amount)).to match_array([500.0, 100.0])
      end

      it 'audit log includes allocation details' do
        result = described_class.call(
          actor:            actor,
          customer:         customer,
          deduction_amount: 300.0,
          advance_payment:  @advance
        )

        audit = AuditLog.where(action: 'advance_auto_applied_to_invoice').first
        expect(audit.changes['deducted_amount']).to eq(300.0)
        expect(audit.changes['invoice_id']).to eq(@inv1.id)
      end
    end
  end
end
