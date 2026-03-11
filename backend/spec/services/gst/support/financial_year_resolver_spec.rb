# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Gst::Support::FinancialYearResolver, type: :service do
  let(:org) { create(:organization) }
  subject(:resolver) { described_class.new(organization: org) }

  describe '.fiscal_start_year_for_date' do
    it 'returns same year for dates in April–December' do
      expect(described_class.fiscal_start_year_for_date(Date.new(2025, 4, 1))).to eq(2025)
      expect(described_class.fiscal_start_year_for_date(Date.new(2025, 9, 15))).to eq(2025)
      expect(described_class.fiscal_start_year_for_date(Date.new(2025, 12, 31))).to eq(2025)
    end

    it 'returns previous year for dates in January–March' do
      expect(described_class.fiscal_start_year_for_date(Date.new(2026, 1, 1))).to eq(2025)
      expect(described_class.fiscal_start_year_for_date(Date.new(2026, 3, 31))).to eq(2025)
    end
  end

  describe '.code_for_fiscal_start_year' do
    it 'formats as FY20XX-YY' do
      expect(described_class.code_for_fiscal_start_year(2025)).to eq('FY2025-26')
      expect(described_class.code_for_fiscal_start_year(2024)).to eq('FY2024-25')
    end
  end

  describe '#resolve_for_date' do
    context 'when a FinancialYear exists for the date' do
      let!(:fy) { create(:financial_year, organization: org, code: 'FY2025-26',
                          start_date: Date.new(2025, 4, 1), end_date: Date.new(2026, 3, 31)) }

      it 'returns the matching FinancialYear' do
        expect(resolver.resolve_for_date(Date.new(2025, 9, 15))).to eq(fy)
      end

      it 'returns nil for a date outside the FY' do
        expect(resolver.resolve_for_date(Date.new(2024, 3, 31))).to be_nil
      end
    end

    context 'when no FinancialYear exists' do
      it 'returns nil' do
        expect(resolver.resolve_for_date(Date.new(2025, 9, 15))).to be_nil
      end
    end
  end

  describe '#find_or_create_for_date!' do
    it 'creates a new FinancialYear when none exists' do
      expect {
        fy = resolver.find_or_create_for_date!(Date.new(2025, 9, 15))
        expect(fy).to be_persisted
        expect(fy.code).to eq('FY2025-26')
        expect(fy.start_date).to eq(Date.new(2025, 4, 1))
        expect(fy.end_date).to eq(Date.new(2026, 3, 31))
        expect(fy.status).to eq('open')
      }.to change(FinancialYear, :count).by(1)
    end

    it 'returns existing FY without creating a duplicate' do
      existing = create(:financial_year, organization: org, code: 'FY2025-26',
                         start_date: Date.new(2025, 4, 1), end_date: Date.new(2026, 3, 31))
      expect {
        result = resolver.find_or_create_for_date!(Date.new(2025, 7, 1))
        expect(result).to eq(existing)
      }.not_to change(FinancialYear, :count)
    end

    it 'creates FY correctly for January (cross-year boundary)' do
      fy = resolver.find_or_create_for_date!(Date.new(2026, 1, 15))
      expect(fy.code).to eq('FY2025-26')
    end

    it 'creates FY correctly for March 31 (last day of FY)' do
      fy = resolver.find_or_create_for_date!(Date.new(2026, 3, 31))
      expect(fy.code).to eq('FY2025-26')
    end
  end

  describe '#find_or_create_for_period!' do
    it 'creates FY from month/year' do
      fy = resolver.find_or_create_for_period!(month: 9, year: 2025)
      expect(fy.code).to eq('FY2025-26')
    end
  end
end
