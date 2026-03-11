# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GstReturnPeriod, type: :model do
  let(:org) { create(:organization) }
  let(:fy)  { create(:financial_year, organization: org) }

  describe 'validations' do
    subject(:period) do
      build(:gst_return_period, organization: org, financial_year: fy)
    end

    it { is_expected.to be_valid }

    it 'rejects invalid return_type' do
      period.return_type = 'gstr9'
      expect(period).not_to be_valid
    end

    it 'rejects invalid status' do
      period.status = 'pending'
      expect(period).not_to be_valid
    end

    it 'rejects month outside 1-12' do
      period.month = 13
      expect(period).not_to be_valid
    end

    it 'rejects period dates outside financial year' do
      period.period_start_on = Date.new(2024, 1, 1)
      period.period_end_on   = Date.new(2024, 1, 31)
      expect(period).not_to be_valid
      expect(period.errors[:base]).to include(/must fall within/)
    end
  end

  describe '#display_name' do
    it 'formats the display name correctly' do
      period = build(:gst_return_period, month: 9, year: 2025, return_type: 'gstr1')
      expect(period.display_name).to include('September')
      expect(period.display_name).to include('2025')
      expect(period.display_name).to include('GSTR1')
    end
  end

  describe '#filing_period_code' do
    it 'returns MMYYYY format' do
      period = build(:gst_return_period, month: 9, year: 2025)
      expect(period.filing_period_code).to eq('092025')
    end

    it 'zero-pads single-digit months' do
      period = build(:gst_return_period, month: 3, year: 2026)
      expect(period.filing_period_code).to eq('032026')
    end
  end

  describe 'lifecycle transitions' do
    let(:user)   { create(:user) }
    let(:period) { create(:gst_return_period, organization: org, financial_year: fy) }

    describe '#mark_generated!' do
      it 'transitions to generated status' do
        period.mark_generated!(source_hash: 'abc123', error_count: 0)
        expect(period.reload.status).to eq('generated')
        expect(period.generated_at).to be_present
      end
    end

    describe '#lock!' do
      it 'cannot lock a draft period' do
        expect { period.lock!(by_user: user) }.to raise_error(RuntimeError)
      end

      it 'locks a generated period' do
        period.mark_generated!
        period.lock!(by_user: user)
        expect(period.reload.status).to eq('locked')
        expect(period.locked_at).to be_present
      end
    end

    describe '#file!' do
      it 'cannot file a generated (unlocked) period' do
        period.mark_generated!
        expect { period.file!(by_user: user) }.to raise_error(RuntimeError)
      end

      it 'files a locked period' do
        period.mark_generated!
        period.lock!(by_user: user)
        period.file!(by_user: user, notes: 'Filed via portal')
        expect(period.reload.status).to eq('filed')
        expect(period.filed_at).to be_present
      end
    end

    describe '#reopen!' do
      it 'reopens a filed period' do
        period.mark_generated!
        period.lock!(by_user: user)
        period.file!(by_user: user)
        period.reopen!(by_user: user, reason: 'Amendment needed')
        expect(period.reload.status).to eq('generated')
      end

      it 'cannot reopen a draft period' do
        expect { period.reopen!(by_user: user, reason: 'test') }.to raise_error(RuntimeError)
      end
    end
  end
end
