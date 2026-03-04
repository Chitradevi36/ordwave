require 'rails_helper'

RSpec.describe HsnSacCode, type: :model do
  subject(:code) { build(:hsn_sac_code) }

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------
  describe 'validations' do
    it { is_expected.to be_valid }

    it 'is invalid without a code' do
      code.code = nil
      expect(code).not_to be_valid
      expect(code.errors[:code]).to include("can't be blank")
    end

    it 'is invalid without a code_type' do
      code.code_type = nil
      expect(code).not_to be_valid
    end

    it 'rejects unknown code_type' do
      code.code_type = 'XYZ'
      expect(code).not_to be_valid
      expect(code.errors[:code_type]).to be_present
    end

    it 'is invalid without gst_rate' do
      code.gst_rate = nil
      expect(code).not_to be_valid
    end

    it 'rejects a non-standard GST rate' do
      code.gst_rate = 15
      expect(code).not_to be_valid
      expect(code.errors[:gst_rate]).to be_present
    end

    it 'accepts all standard GST rates' do
      [0, 5, 12, 18, 28].each do |rate|
        code.gst_rate = rate
        expect(code).to be_valid, "expected #{rate}% to be valid"
      end
    end

    it 'is invalid without effective_from' do
      code.effective_from = nil
      expect(code).not_to be_valid
    end

    context 'when effective_to is present' do
      it 'is invalid when effective_to <= effective_from' do
        code.effective_from = Date.new(2024, 1, 1)
        code.effective_to   = Date.new(2024, 1, 1)
        expect(code).not_to be_valid
        expect(code.errors[:effective_to]).to be_present
      end

      it 'is valid when effective_to > effective_from' do
        code.effective_from = Date.new(2024, 1, 1)
        code.effective_to   = Date.new(2024, 12, 31)
        expect(code).to be_valid
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Callbacks — split rates
  # ---------------------------------------------------------------------------
  describe '#compute_split_rates (before_validation)' do
    it 'sets igst_rate = gst_rate' do
      code.gst_rate = 18
      code.valid?
      expect(code.igst_rate).to eq(18)
    end

    it 'splits cgst and sgst at half the gst_rate' do
      code.gst_rate = 18
      code.valid?
      expect(code.cgst_rate).to eq(9)
      expect(code.sgst_rate).to eq(9)
    end

    it 'handles odd rates without rounding error (e.g. 5%)' do
      code.gst_rate = 5
      code.valid?
      expect(code.cgst_rate).to eq(2.5)
      expect(code.sgst_rate).to eq(2.5)
      expect(code.igst_rate).to eq(5)
    end

    it 'sets zero rates for 0% GST' do
      code.gst_rate = 0
      code.valid?
      expect(code.cgst_rate).to eq(0)
      expect(code.sgst_rate).to eq(0)
      expect(code.igst_rate).to eq(0)
    end
  end

  # ---------------------------------------------------------------------------
  # Normalise code callback
  # ---------------------------------------------------------------------------
  describe '#normalise_code (before_validation)' do
    it 'upcases and strips whitespace' do
      code.code = '  10061090 '
      code.valid?
      expect(code.code).to eq('10061090')
    end
  end

  # ---------------------------------------------------------------------------
  # Scopes
  # ---------------------------------------------------------------------------
  describe 'scopes' do
    let!(:current_hsn)    { create(:hsn_sac_code, active: true,  effective_to: nil)   }
    let!(:inactive_hsn)   { create(:hsn_sac_code, active: false, effective_to: nil)   }
    let!(:historical_hsn) { create(:hsn_sac_code, active: true,  effective_to: Date.current - 1.day) }

    describe '.active' do
      it 'includes active records regardless of effective_to' do
        expect(described_class.active).to include(current_hsn, historical_hsn)
      end

      it 'excludes inactive records' do
        expect(described_class.active).not_to include(inactive_hsn)
      end
    end

    describe '.current' do
      it 'includes only active records with no end date' do
        expect(described_class.current).to include(current_hsn)
      end

      it 'excludes inactive records' do
        expect(described_class.current).not_to include(inactive_hsn)
      end

      it 'excludes records with an effective_to date' do
        expect(described_class.current).not_to include(historical_hsn)
      end
    end

    describe '.by_code' do
      it 'finds a record by code (case-insensitive input)' do
        rec = create(:hsn_sac_code, code: 'ABCD1234')
        expect(described_class.by_code('abcd1234')).to include(rec)
      end
    end

    describe '.with_type' do
      it 'filters by code_type' do
        hsn = create(:hsn_sac_code, code_type: 'HSN')
        sac = create(:hsn_sac_code, code_type: 'SAC')
        expect(described_class.with_type('HSN')).to include(hsn)
        expect(described_class.with_type('HSN')).not_to include(sac)
      end
    end

    describe '.effective_on' do
      it 'returns records whose window covers the query date' do
        rec = create(:hsn_sac_code,
                     effective_from: Date.new(2023, 1, 1),
                     effective_to:   Date.new(2023, 12, 31))
        expect(described_class.effective_on(Date.new(2023, 6, 1))).to include(rec)
      end

      it 'excludes records outside the window' do
        rec = create(:hsn_sac_code,
                     effective_from: Date.new(2023, 1, 1),
                     effective_to:   Date.new(2023, 12, 31))
        expect(described_class.effective_on(Date.new(2024, 1, 1))).not_to include(rec)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Instance methods
  # ---------------------------------------------------------------------------
  describe '#current_rate?' do
    it 'returns true when active and effective_to is nil' do
      code.active = true
      code.effective_to = nil
      expect(code.current_rate?).to be true
    end

    it 'returns false when inactive' do
      code.active = false
      code.effective_to = nil
      expect(code.current_rate?).to be false
    end

    it 'returns false when effective_to is set' do
      code.active = true
      code.effective_to = Date.current
      expect(code.current_rate?).to be false
    end
  end
end
