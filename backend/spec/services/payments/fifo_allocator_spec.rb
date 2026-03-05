require 'rails_helper'

RSpec.describe Payments::FifoAllocator, type: :service do
  let(:org)      { create(:organization) }
  let(:branch)   { create(:branch, organization: org) }
  let(:customer) { create(:customer, organization: org) }
  let(:actor)    { create(:user) }

  def make_invoice(grand_total:, outstanding_amount: nil, days_ago: 0, status: 'issued')
    create(:sales_invoice,
           organization:       org,
           branch:             branch,
           customer:           customer,
           created_by:         actor,
           grand_total:        grand_total,
           outstanding_amount: outstanding_amount || grand_total,
           paid_amount:        grand_total - (outstanding_amount || grand_total),
           status:             status,
           invoice_date:       Date.today - days_ago.days,
           issued_at:          Time.current - days_ago.days)
  end

  describe '.run' do
    context 'with a single invoice fully covered by payment' do
      let!(:inv) { make_invoice(grand_total: 1_000.0, days_ago: 5) }

      it 'allocates the full invoice amount' do
        result = described_class.run(customer: customer, amount: 1_000.0)
        expect(result.allocations.size).to eq(1)
        expect(result.allocations.first[:allocated]).to eq(1_000.0)
        expect(result.unallocated).to eq(0.0)
      end
    end

    context 'with a partial payment' do
      let!(:inv) { make_invoice(grand_total: 2_000.0, days_ago: 5) }

      it 'partially allocates and returns zero unallocated' do
        result = described_class.run(customer: customer, amount: 1_200.0)
        expect(result.allocations.first[:allocated]).to eq(1_200.0)
        expect(result.unallocated).to eq(0.0)
      end
    end

    context 'with payment exceeding total outstanding' do
      let!(:inv) { make_invoice(grand_total: 500.0, days_ago: 5) }

      it 'allocates up to outstanding and returns the remainder as unallocated' do
        result = described_class.run(customer: customer, amount: 800.0)
        expect(result.allocations.first[:allocated]).to eq(500.0)
        expect(result.unallocated).to eq(300.0)
      end
    end

    context 'with multiple invoices (FIFO order)' do
      let!(:old_inv)  { make_invoice(grand_total: 600.0, days_ago: 20) }
      let!(:new_inv)  { make_invoice(grand_total: 800.0, days_ago:  5) }

      it 'allocates oldest invoice first' do
        result = described_class.run(customer: customer, amount: 700.0)
        allocations = result.allocations.sort_by { |a| a[:invoice].invoice_date }
        expect(allocations.first[:invoice].id).to eq(old_inv.id)
        expect(allocations.first[:allocated]).to eq(600.0)
        # Remainder goes to newer invoice
        expect(allocations.second[:allocated]).to eq(100.0)
        expect(result.unallocated).to eq(0.0)
      end
    end

    context 'with partially_paid invoice in the pool' do
      let!(:inv) do
        make_invoice(grand_total: 1_000.0, outstanding_amount: 400.0, status: 'partially_paid', days_ago: 10)
      end

      it 'allocates against remaining outstanding only' do
        result = described_class.run(customer: customer, amount: 600.0)
        expect(result.allocations.first[:allocated]).to eq(400.0)
        expect(result.unallocated).to eq(200.0)
      end
    end

    context 'with zero amount' do
      let!(:inv) { make_invoice(grand_total: 1_000.0, days_ago: 5) }

      it 'returns empty allocations and zero unallocated' do
        result = described_class.run(customer: customer, amount: 0)
        expect(result.allocations).to be_empty
        expect(result.unallocated).to eq(0.0)
      end
    end

    context 'with no outstanding invoices' do
      it 'returns all amount as unallocated' do
        result = described_class.run(customer: customer, amount: 500.0)
        expect(result.allocations).to be_empty
        expect(result.unallocated).to eq(500.0)
      end
    end
  end
end
