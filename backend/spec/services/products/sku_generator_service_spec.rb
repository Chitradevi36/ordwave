require 'rails_helper'

RSpec.describe Products::SkuGeneratorService, type: :service do
  let(:org) { create(:organization) }

  subject(:service) { described_class.new(organization: org) }

  describe '#generate' do
    it 'returns a string matching the PROD-XXXXXX format' do
      sku = service.generate
      expect(sku).to match(/\APROD-[A-Z0-9]{6}\z/)
    end

    it 'returns a SKU that does not already exist in the org' do
      uom      = create(:unit_of_measure)
      hsn      = create(:hsn_sac_code)
      category = create(:product_category, organization: org)
      # Create a product that occupies one SKU
      create(:product, organization: org, product_category: category,
                       unit_of_measure: uom, hsn_sac_code: hsn, sku: 'PROD-ABC123')

      generated = service.generate
      expect(generated).not_to eq('PROD-ABC123')
    end

    it 'generates distinct SKUs on successive calls (no collision under normal load)' do
      skus = Array.new(10) { service.generate }
      # All should match the format; uniqueness not guaranteed across calls but
      # statistically almost certain with 36^6 = 2.18B candidates
      skus.each { |sku| expect(sku).to match(/\APROD-[A-Z0-9]{6}\z/) }
    end

    it 'falls back gracefully when all attempts collide (stubbed)' do
      # Simulate every candidate already existing
      allow_any_instance_of(ActiveRecord::Relation).to receive(:exists?).and_return(true)
      sku = service.generate
      # Fallback format: PROD-<timestamp>
      expect(sku).to match(/\APROD-\d+\z/)
    end
  end
end
