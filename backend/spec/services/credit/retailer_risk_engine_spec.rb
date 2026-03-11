# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Credit::RetailerRiskEngine, type: :service do
  let(:org)    { create(:organization) }
  let(:branch) { create(:branch, organization: org) }
  let(:customer) do
    create(:customer, organization: org, branch: branch, credit_days: 30)
  end
  let!(:credit_account) do
    create(:credit_account,
           customer:        customer,
           organization:    org,
           branch:          branch,
           credit_limit:    50_000,
           current_balance: 0,
           available_credit: 50_000,
           overdue_amount:  0,
           overdue_days:    0,
           watchlist:       false)
  end

  describe '.compute' do
    subject(:result) { described_class.compute(customer) }

    context 'with a healthy retailer (no risk signals)' do
      it 'returns score 0' do
        expect(result[:score]).to eq(0)
      end

      it 'assigns low tier' do
        expect(result[:tier]).to eq('low')
      end

      it 'recommends allowing the order' do
        expect(result[:recommendation]).to include('Allow order')
      end

      it 'returns an empty factors list' do
        expect(result[:factors]).to be_empty
      end

      it 'includes score_version v1' do
        expect(result[:score_version]).to eq('v1')
      end
    end

    context 'with overdue days' do
      shared_examples 'overdue scoring' do |days, expected_pts, expected_tier|
        before { credit_account.update!(overdue_days: days) }

        it "scores #{expected_pts} points for #{days} overdue days" do
          expect(result[:score]).to eq(expected_pts)
        end

        it "assigns #{expected_tier} tier for #{days} overdue days" do
          expect(result[:tier]).to eq(expected_tier)
        end

        it 'includes an overdue factor' do
          expect(result[:factors].map { |f| f[:key] }).to include('overdue_days')
        end
      end

      include_examples 'overdue scoring', 5,  5,  'low'
      include_examples 'overdue scoring', 10, 10, 'low'
      include_examples 'overdue scoring', 20, 20, 'low'
      include_examples 'overdue scoring', 35, 27, 'medium'
      include_examples 'overdue scoring', 65, 30, 'medium'
    end

    context 'with high credit utilization' do
      before do
        credit_account.update!(
          credit_limit:    50_000,
          current_balance: 45_000,  # 90% utilization
          available_credit: 5_000,
          overdue_days:    0
        )
      end

      it 'scores 18 points for 90% utilization' do
        expect(result[:score]).to eq(18)
      end

      it 'includes a credit_utilization factor' do
        expect(result[:factors].map { |f| f[:key] }).to include('credit_utilization')
      end
    end

    context 'with over-limit balance' do
      before do
        credit_account.update!(
          credit_limit:    50_000,
          current_balance: 55_000,  # 110% — over limit
          available_credit: 0,
          overdue_days:    0
        )
      end

      it 'scores 25 points for over-limit balance' do
        expect(result[:score]).to eq(25)
      end
    end

    context 'with watchlist flag' do
      before { credit_account.update!(watchlist: true) }

      it 'adds 6 points for watchlist flag' do
        expect(result[:score]).to eq(6)
      end

      it 'includes a watchlist factor' do
        expect(result[:factors].map { |f| f[:key] }).to include('watchlist')
      end
    end

    context 'with multiple reversals' do
      before do
        3.times do
          create(:payment,
                 customer:      customer,
                 organization:  org,
                 branch:        branch,
                 status:        'reversed',
                 received_date: 2.months.ago)
        end
      end

      it 'scores 18 points for 3 reversals' do
        expect(result[:score]).to eq(18)
      end

      it 'includes a payment_reversals factor' do
        expect(result[:factors].map { |f| f[:key] }).to include('payment_reversals')
      end
    end

    context 'with inactive customer (no recent orders)' do
      it 'scores 6 points for order frequency drop' do
        expect(result[:score]).to eq(6)
      end

      it 'includes an order_frequency factor' do
        expect(result[:factors].map { |f| f[:key] }).to include('order_frequency')
      end
    end

    context 'with a very risky combination of signals' do
      before do
        # 30 pts overdue
        credit_account.update!(
          overdue_days:    65,
          current_balance: 48_000,  # 96% util → 22 pts
          available_credit: 2_000,
          watchlist:       true     # +6 pts
        )
        # 18 pts from 3 reversals
        3.times do
          create(:payment,
                 customer: customer, organization: org, branch: branch,
                 status: 'reversed', received_date: 1.month.ago)
        end
      end

      it 'is clamped to 100 maximum' do
        expect(result[:score]).to be <= 100
      end

      it 'assigns critical tier' do
        expect(result[:tier]).to eq('critical')
      end

      it 'recommends blocking' do
        expect(result[:recommendation]).to include('Block order')
      end
    end

    context 'without a credit account' do
      before { credit_account.destroy }

      it 'returns score 0' do
        expect(result[:score]).to eq(0)
      end

      it 'assigns low tier' do
        expect(result[:tier]).to eq('low')
      end

      it 'returns a no_data factor' do
        expect(result[:factors].first[:key]).to eq('no_data')
      end
    end
  end

  describe '.compute_and_save!' do
    it 'creates a RetailerRiskSnapshot record' do
      expect {
        described_class.compute_and_save!(customer)
      }.to change(RetailerRiskSnapshot, :count).by(1)
    end

    it 'persists the correct risk_tier' do
      snap = described_class.compute_and_save!(customer)
      expect(snap.risk_tier).to eq('low')
    end

    it 'sets computed_at to now' do
      snap = described_class.compute_and_save!(customer)
      expect(snap.computed_at).to be_within(5.seconds).of(Time.current)
    end

    context 'when called twice' do
      it 'overwrites the existing snapshot (upsert by customer)' do
        described_class.compute_and_save!(customer)
        expect {
          described_class.compute_and_save!(customer)
        }.not_to change(RetailerRiskSnapshot, :count)
      end
    end
  end

  describe 'tier boundaries' do
    it 'scores in 0–24 → low' do
      expect(described_class::TIER_THRESHOLDS['low']).to eq(0)
    end

    it 'scores 25–49 → medium' do
      expect(described_class::TIER_THRESHOLDS['medium']).to eq(25)
    end

    it 'scores 50–74 → high' do
      expect(described_class::TIER_THRESHOLDS['high']).to eq(50)
    end

    it 'scores 75–100 → critical' do
      expect(described_class::TIER_THRESHOLDS['critical']).to eq(75)
    end
  end
end
