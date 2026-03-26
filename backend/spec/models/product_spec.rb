# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Product, type: :model do
  subject { build(:product) }

  # ── Associations ────────────────────────────────────────────────────────────

  describe 'associations' do
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to belong_to(:product_category) }
    it { is_expected.to belong_to(:units_of_measure).class_name('UnitsOfMeasure') }
    it { is_expected.to belong_to(:hsn_sac_code) }
    it { is_expected.to have_many(:price_list_items).dependent(:restrict_with_error) }
  end

  # ── Validations ─────────────────────────────────────────────────────────────

  describe 'validations' do
    it { is_expected.to validate_presence_of(:sku) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:sku).is_at_most(50) }
    it { is_expected.to validate_length_of(:name).is_at_most(150) }
    it { is_expected.to validate_numericality_of(:min_order_qty).is_greater_than(0) }

    it { is_expected.to validate_inclusion_of(:status).in_array(Product::VALID_STATUSES) }
    it { is_expected.to validate_inclusion_of(:gst_rate).in_array(Product::VALID_GST_RATES) }

    context 'SKU format' do
      it 'allows uppercase alphanumeric with hyphens and underscores' do
        subject.sku = 'PROD-001_A'
        subject.valid?
        expect(subject.errors[:sku]).not_to include(match(/only uppercase/))
      end

      it 'rejects lowercase or special characters' do
        subject.sku = 'prod 001!'
        subject.valid?
        expect(subject.errors[:sku]).to include(match(/only uppercase/))
      end
    end

    context 'SKU uniqueness scoped to organization' do
      let!(:existing) { create(:product) }

      it 'rejects duplicate SKU within the same org' do
        dup = build(:product, organization: existing.organization, sku: existing.sku)
        expect(dup).not_to be_valid
        expect(dup.errors[:sku]).to include(match(/already been taken/))
      end

      it 'allows same SKU in different orgs' do
        other_org = create(:organization)
        different_org_product = build(:product, organization: other_org, sku: existing.sku)
        expect(different_org_product).to be_valid
      end
    end
  end

  # ── Callbacks ───────────────────────────────────────────────────────────────

  describe 'callbacks' do
    it 'upcases SKU before validation' do
      product = build(:product, sku: 'prod-001')
      product.valid?
      expect(product.sku).to eq('PROD-001')
    end

    it 'auto-fills GST rate from HSN code when HSN changes' do
      hsn = create(:hsn_sac_code, gst_rate: 18)
      product = build(:product, hsn_sac_code: hsn, gst_rate: 5)
      product.valid?
      expect(product.gst_rate).to eq(18)
    end
  end

  # ── Scopes ──────────────────────────────────────────────────────────────────

  describe 'scopes' do
    let!(:org) { create(:organization) }
    let!(:active_product)       { create(:product, organization: org, status: 'active') }
    let!(:discontinued_product) { create(:product, organization: org, status: 'discontinued') }

    describe '.active' do
      it 'returns only active, non-deleted products' do
        expect(Product.active).to include(active_product)
        expect(Product.active).not_to include(discontinued_product)
      end
    end

    describe '.for_org' do
      it 'scopes to the given organization' do
        other = create(:product, organization: create(:organization))
        expect(Product.for_org(org.id)).to include(active_product)
        expect(Product.for_org(org.id)).not_to include(other)
      end
    end

    describe '.search_sku_name' do
      it 'matches on SKU or name (case-insensitive)' do
        results = Product.search_sku_name(active_product.sku[0..3])
        expect(results).to include(active_product)
      end
    end
  end

  # ── Instance methods ────────────────────────────────────────────────────────

  describe '#soft_delete!' do
    let(:product) { create(:product) }

    it 'sets deleted_at and discontinues the product' do
      product.soft_delete!
      expect(product.deleted_at).to be_present
      expect(product.status).to eq('discontinued')
    end
  end

  describe '#gsplit_rates' do
    it 'splits GST equally into CGST and SGST' do
      product = build(:product, gst_rate: 18)
      expect(product.gsplit_rates).to eq({ cgst: 9.0, sgst: 9.0, igst: 18 })
    end
  end
end
