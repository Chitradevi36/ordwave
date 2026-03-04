require 'rails_helper'

RSpec.describe Gst::GstCalculator do
  # Helpers — lightweight doubles that satisfy the .state_code / .gstin interface
  def make_branch(state_code)
    double('Branch', state_code: state_code)
  end

  def make_customer(gstin)
    double('Customer', gstin: gstin)
  end

  describe '.calculate' do
    context 'intra-state transaction (same state code)' do
      let(:branch)   { make_branch('27') }          # Maharashtra
      let(:customer) { make_customer('27ABCDE1234F1Z5') }

      subject { described_class.calculate(branch: branch, customer: customer, gst_rate: 18, taxable_value: 1_000) }

      it 'returns intra_state: true' do
        expect(subject.intra_state).to be true
      end

      it 'splits into CGST and SGST at half the rate' do
        expect(subject.cgst_rate).to eq(9)
        expect(subject.sgst_rate).to eq(9)
        expect(subject.igst_rate).to eq(0)
      end

      it 'computes correct tax amounts' do
        expect(subject.cgst_amount).to eq(90)
        expect(subject.sgst_amount).to eq(90)
        expect(subject.igst_amount).to eq(0)
      end

      it 'totals correctly' do
        expect(subject.total_tax).to eq(180)
      end
    end

    context 'inter-state transaction (different state codes)' do
      let(:branch)   { make_branch('27') }           # Maharashtra
      let(:customer) { make_customer('07ABCDE1234F1Z5') } # Delhi

      subject { described_class.calculate(branch: branch, customer: customer, gst_rate: 18, taxable_value: 1_000) }

      it 'returns intra_state: false' do
        expect(subject.intra_state).to be false
      end

      it 'charges only IGST' do
        expect(subject.cgst_rate).to eq(0)
        expect(subject.sgst_rate).to eq(0)
        expect(subject.igst_rate).to eq(18)
      end

      it 'computes correct tax amounts' do
        expect(subject.cgst_amount).to eq(0)
        expect(subject.sgst_amount).to eq(0)
        expect(subject.igst_amount).to eq(180)
      end

      it 'totals correctly' do
        expect(subject.total_tax).to eq(180)
      end
    end

    context 'customer has no GSTIN (B2C or unregistered)' do
      let(:branch)   { make_branch('27') }
      let(:customer) { make_customer(nil) }

      subject { described_class.calculate(branch: branch, customer: customer, gst_rate: 12, taxable_value: 500) }

      it 'falls back to intra-state split (conservative)' do
        expect(subject.intra_state).to be true
      end

      it 'splits CGST/SGST' do
        expect(subject.cgst_rate).to eq(6)
        expect(subject.sgst_rate).to eq(6)
      end
    end

    context 'branch has no state_code' do
      let(:branch)   { make_branch(nil) }
      let(:customer) { make_customer('27ABCDE1234F1Z5') }

      subject { described_class.calculate(branch: branch, customer: customer, gst_rate: 5, taxable_value: 200) }

      it 'falls back to intra-state split (conservative)' do
        expect(subject.intra_state).to be true
      end
    end

    context '0% GST rate' do
      let(:branch)   { make_branch('07') }
      let(:customer) { make_customer('27ABCDE1234F1Z5') }

      subject { described_class.calculate(branch: branch, customer: customer, gst_rate: 0, taxable_value: 1_000) }

      it 'results in zero tax across all components' do
        expect(subject.cgst_amount).to eq(0)
        expect(subject.sgst_amount).to eq(0)
        expect(subject.igst_amount).to eq(0)
        expect(subject.total_tax).to eq(0)
      end
    end

    context 'precision — 28% on a fractional value' do
      let(:branch)   { make_branch('29') }
      let(:customer) { make_customer('29ABCDE1234F1Z5') } # same state

      subject { described_class.calculate(branch: branch, customer: customer, gst_rate: 28, taxable_value: 123.45) }

      it 'amounts are rounded to 2 decimal places' do
        expect(subject.cgst_amount.to_s).to match(/\A\d+\.\d{1,2}\z/)
        expect(subject.sgst_amount.to_s).to match(/\A\d+\.\d{1,2}\z/)
        expect(subject.total_tax).to eq((subject.cgst_amount + subject.sgst_amount + subject.igst_amount).round(2))
      end
    end
  end
end
