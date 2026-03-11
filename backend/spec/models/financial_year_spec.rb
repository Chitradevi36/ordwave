# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FinancialYear, type: :model do
  let(:org) { create(:organization) }

  describe 'validations' do
    subject(:fy) do
      build(:financial_year, organization: org,
            code: 'FY2025-26', start_date: Date.new(2025, 4, 1), end_date: Date.new(2026, 3, 31))
    end

    it { is_expected.to be_valid }

    it 'requires code' do
      fy.code = nil
      expect(fy).not_to be_valid
      expect(fy.errors[:code]).to include("can't be blank")
    end

    it 'enforces unique code per organization' do
      create(:financial_year, organization: org, code: 'FY2025-26',
             start_date: Date.new(2025, 4, 1), end_date: Date.new(2026, 3, 31))
      expect(fy).not_to be_valid
      expect(fy.errors[:code]).to include('has already been taken')
    end

    it 'allows same code for different organizations' do
      other_org = create(:organization)
      create(:financial_year, organization: other_org, code: 'FY2025-26',
             start_date: Date.new(2025, 4, 1), end_date: Date.new(2026, 3, 31))
      expect(fy).to be_valid
    end

    it 'rejects end_date <= start_date' do
      fy.end_date = fy.start_date
      expect(fy).not_to be_valid
      expect(fy.errors[:end_date]).to include('must be after start_date')
    end

    it 'rejects invalid status' do
      fy.status = 'banana'
      expect(fy).not_to be_valid
    end
  end

  describe '#includes_date?' do
    let(:fy) { build(:financial_year, start_date: Date.new(2025, 4, 1), end_date: Date.new(2026, 3, 31)) }

    it 'returns true for a date within FY' do
      expect(fy.includes_date?(Date.new(2025, 9, 15))).to be true
    end

    it 'returns false for a date before FY' do
      expect(fy.includes_date?(Date.new(2025, 3, 31))).to be false
    end

    it 'returns false for a date after FY' do
      expect(fy.includes_date?(Date.new(2026, 4, 1))).to be false
    end

    it 'includes boundary dates' do
      expect(fy.includes_date?(Date.new(2025, 4, 1))).to be true
      expect(fy.includes_date?(Date.new(2026, 3, 31))).to be true
    end
  end

  describe '#calendar_months' do
    let(:fy) { build(:financial_year, start_date: Date.new(2025, 4, 1), end_date: Date.new(2026, 3, 31)) }

    it 'returns 12 months' do
      expect(fy.calendar_months.length).to eq(12)
    end

    it 'starts from April' do
      expect(fy.calendar_months.first).to eq({ month: 4, year: 2025 })
    end

    it 'ends in March of the next year' do
      expect(fy.calendar_months.last).to eq({ month: 3, year: 2026 })
    end
  end

  describe 'status helpers' do
    it 'responds to open?, locked?, closed?, archived?' do
      fy = build(:financial_year, status: 'open')
      expect(fy.open?).to be true
      expect(fy.locked?).to be false
      expect(fy.closed?).to be false
    end
  end

  describe '#closing_checklist' do
    let(:fy) { create(:financial_year, organization: org) }

    it 'returns ready_to_close: true when no open periods or issues' do
      checklist = fy.closing_checklist
      expect(checklist[:ready_to_close]).to be true
    end

    it 'returns ready_to_close: false when unfiled GSTR-1 periods exist' do
      create(:gst_return_period, organization: org, financial_year: fy,
             return_type: 'gstr1', status: 'draft')
      checklist = fy.closing_checklist
      expect(checklist[:ready_to_close]).to be false
      failing = checklist[:checklist].find { |c| c[:item] == 'all_gstr1_periods_filed' }
      expect(failing[:status]).to eq('fail')
    end
  end
end
