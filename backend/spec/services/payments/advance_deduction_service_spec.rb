require 'rails_helper'

RSpec.describe Payments::AdvanceDeductionService, type: :service do
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

  describe '.call' do
    context 'no available advances' do
      it 'returns zero deduction' do
        result = described_class.call(
          customer:       customer,
          payment_amount: 500.0,
          organization:   org
        )

        expect(result.advance_deducted).to eq(0.to_d)
        expect(result.remaining_payment).to eq(500.0.to_d)
        expect(result.advance_used).to be_nil
      end

      it 'preserves full payment amount' do
        result = described_class.call(
          customer:       customer,
          payment_amount: 750.50,
          organization:   org
        )

        expect(result.remaining_payment).to eq(750.50.to_d)
      end
    end

    context 'with single unapplied advance' do
      before do
        @payment = create(:payment, organization: org, branch: branch, customer: customer,
                         amount: 500, status: 'draft')
        @advance = create(:advance_payment, organization: org, branch: branch,
                         customer: customer, source_payment: @payment,
                         original_amount: 300, balance: 300, status: 'unapplied')
      end

      it 'deducts available advance balance' do
        result = described_class.call(
          customer:       customer,
          payment_amount: 500.0,
          organization:   org
        )

        expect(result.advance_deducted).to eq(300.0.to_d)
        expect(result.remaining_payment).to eq(200.0.to_d)
        expect(result.advance_used).to eq(@advance)
      end

      it 'deducts partial advance when payment is less than advance' do
        result = described_class.call(
          customer:       customer,
          payment_amount: 200.0,
          organization:   org
        )

        expect(result.advance_deducted).to eq(200.0.to_d)
        expect(result.remaining_payment).to eq(0.to_d)
      end

      it 'deducts full advance when payment exceeds it' do
        result = described_class.call(
          customer:       customer,
          payment_amount: 500.0,
          organization:   org
        )

        expect(result.advance_deducted).to eq(300.0.to_d)
      end
    end

    context 'with multiple advances (FIFO)' do
      before do
        payment1 = create(:payment, organization: org, branch: branch, customer: customer, amount: 200)
        payment2 = create(:payment, organization: org, branch: branch, customer: customer, amount: 200)

        @advance1 = create(:advance_payment, organization: org, branch: branch, customer: customer,
                          source_payment: payment1, original_amount: 200, balance: 200,
                          status: 'unapplied', created_at: 2.days.ago)
        @advance2 = create(:advance_payment, organization: org, branch: branch, customer: customer,
                          source_payment: payment2, original_amount: 200, balance: 150,
                          status: 'unapplied', created_at: 1.day.ago)
      end

      it 'applies first advance (oldest) first' do
        result = described_class.call(
          customer:       customer,
          payment_amount: 500.0,
          organization:   org
        )

        expect(result.advance_used).to eq(@advance1)
        expect(result.advance_deducted).to eq(350.0.to_d) # 200 from @advance1 + 150 from @advance2
      end

      it 'deducts from first advance then second' do
        result = described_class.call(
          customer:       customer,
          payment_amount: 250.0,
          organization:   org
        )

        # Should take 200 from first, 50 from second
        expect(result.advance_deducted).to eq(250.0.to_d)
        expect(result.remaining_payment).to eq(0.to_d)
      end

      it 'respects FIFO without over-deducting from later advances' do
        result = described_class.call(
          customer:       customer,
          payment_amount: 180.0,
          organization:   org
        )

        # Should only take from first advance
        expect(result.advance_deducted).to eq(180.0.to_d)
        expect(result.advance_used).to eq(@advance1)
      end
    end

    context 'with partially applied advance' do
      before do
        payment = create(:payment, organization: org, branch: branch, customer: customer, amount: 200)
        @advance = create(:advance_payment, organization: org, branch: branch, customer: customer,
                         source_payment: payment, original_amount: 200, balance: 100,
                         status: 'partially_applied')
      end

      it 'deducts from partially applied advance' do
        result = described_class.call(
          customer:       customer,
          payment_amount: 500.0,
          organization:   org
        )

        expect(result.advance_deducted).to eq(100.0.to_d)
        expect(result.remaining_payment).to eq(400.0.to_d)
      end
    end

    context 'with applied advance (zero balance)' do
      before do
        payment = create(:payment, organization: org, branch: branch, customer: customer, amount: 200)
        @advance = create(:advance_payment, organization: org, branch: branch, customer: customer,
                         source_payment: payment, original_amount: 200, balance: 0,
                         status: 'applied')
      end

      it 'does not deduct from fully applied advance' do
        result = described_class.call(
          customer:       customer,
          payment_amount: 500.0,
          organization:   org
        )

        expect(result.advance_deducted).to eq(0.to_d)
        expect(result.remaining_payment).to eq(500.0.to_d)
      end
    end

    context 'with zero payment amount' do
      before do
        payment = create(:payment, organization: org, branch: branch, customer: customer, amount: 200)
        @advance = create(:advance_payment, organization: org, branch: branch, customer: customer,
                         source_payment: payment, original_amount: 200, balance: 200,
                         status: 'unapplied')
      end

      it 'deducts zero when payment amount is zero' do
        result = described_class.call(
          customer:       customer,
          payment_amount: 0.0,
          organization:   org
        )

        expect(result.advance_deducted).to eq(0.to_d)
        expect(result.remaining_payment).to eq(0.to_d)
      end
    end

    context 'cross-organization isolation' do
      let(:other_org) { create(:organization) }
      let(:other_branch) { create(:branch, organization: other_org) }
      let(:other_customer) { create(:customer, organization: other_org, branch: other_branch) }

      before do
        payment = create(:payment, organization: org, branch: branch, customer: customer, amount: 200)
        @advance = create(:advance_payment, organization: org, branch: branch, customer: customer,
                         source_payment: payment, original_amount: 200, balance: 200,
                         status: 'unapplied')

        other_payment = create(:payment, organization: other_org, branch: other_branch,
                              customer: other_customer, amount: 300)
        other_advance = create(:advance_payment, organization: other_org, branch: other_branch,
                              customer: other_customer, source_payment: other_payment,
                              original_amount: 300, balance: 300, status: 'unapplied')
      end

      it 'only considers advances from same organization' do
        result = described_class.call(
          customer:       customer,
          payment_amount: 500.0,
          organization:   org
        )

        expect(result.advance_deducted).to eq(200.0.to_d) # Only customer's org advance
      end

      it 'does not cross-contaminate across organizations' do
        result = described_class.call(
          customer:       other_customer,
          payment_amount: 500.0,
          organization:   other_org
        )

        expect(result.advance_deducted).to eq(300.0.to_d) # Only other_org advances
      end
    end
  end
end
