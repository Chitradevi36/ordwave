require 'rails_helper'

RSpec.describe Supplier, type: :model do
  let(:org) { create(:organization) }

  describe 'validations' do
    subject do
      build(:supplier, organization: org, name: 'Test Supplier', code: 'SUPP-001')
    end

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:code) }
    it { is_expected.to validate_inclusion_of(:status).in_array(Supplier::STATUSES) }
    it { is_expected.to validate_inclusion_of(:payment_terms_days).in_array(Supplier::PAYMENT_TERMS) }

    it 'validates GSTIN format' do
      supplier = build(:supplier, organization: org, gstin: 'INVALID')
      expect(supplier).not_to be_valid
      expect(supplier.errors[:gstin]).to be_present
    end

    it 'accepts a valid GSTIN' do
      supplier = build(:supplier, organization: org, gstin: '29ABCDE1234F1Z5')
      expect(supplier).to be_valid
    end

    it 'allows blank GSTIN' do
      supplier = build(:supplier, organization: org, gstin: '')
      expect(supplier).to be_valid
    end

    it 'validates PAN format' do
      supplier = build(:supplier, organization: org, pan: 'INVALID')
      expect(supplier).not_to be_valid
      expect(supplier.errors[:pan]).to be_present
    end

    it 'accepts a valid PAN' do
      supplier = build(:supplier, organization: org, pan: 'ABCDE1234F')
      expect(supplier).to be_valid
    end

    it 'validates IFSC format' do
      supplier = build(:supplier, organization: org, bank_ifsc: 'BAD')
      expect(supplier).not_to be_valid
    end

    it 'accepts a valid IFSC' do
      supplier = build(:supplier, organization: org, bank_ifsc: 'SBIN0001234')
      expect(supplier).to be_valid
    end

    it 'validates code uniqueness per org (excluding soft-deleted)' do
      create(:supplier, organization: org, code: 'SUPP-001')
      dup = build(:supplier, organization: org, code: 'SUPP-001')
      expect(dup).not_to be_valid
      expect(dup.errors[:code]).to be_present
    end

    it 'allows same code in different orgs' do
      org2 = create(:organization)
      create(:supplier, organization: org,  code: 'SUPP-001')
      other = build(:supplier, organization: org2, code: 'SUPP-001')
      expect(other).to be_valid
    end

    it 'allows reuse of code from a soft-deleted supplier' do
      s = create(:supplier, organization: org, code: 'SUPP-001')
      s.soft_delete!
      new_s = build(:supplier, organization: org, code: 'SUPP-001')
      expect(new_s).to be_valid
    end
  end

  describe 'soft_delete!' do
    it 'sets deleted_at and status to inactive' do
      supplier = create(:supplier, organization: org, status: 'active')
      expect { supplier.soft_delete! }.to change(supplier, :deleted_at).from(nil)
      expect(supplier.status).to eq('inactive')
    end
  end

  describe 'blacklist!' do
    it 'sets status to blacklisted' do
      supplier = create(:supplier, organization: org, status: 'active')
      supplier.blacklist!
      expect(supplier.reload.status).to eq('blacklisted')
    end
  end

  describe 'activate!' do
    it 'sets status to active' do
      supplier = create(:supplier, organization: org, status: 'blacklisted')
      supplier.activate!
      expect(supplier.reload.status).to eq('active')
    end
  end

  describe 'scopes' do
    let!(:s1) { create(:supplier, organization: org, status: 'active',   name: 'Alpha') }
    let!(:s2) { create(:supplier, organization: org, status: 'inactive', name: 'Beta') }
    let!(:deleted) do
      s = create(:supplier, organization: org, name: 'Gone')
      s.soft_delete!
      s
    end

    it 'not_deleted excludes soft-deleted' do
      ids = Supplier.not_deleted.pluck(:id)
      expect(ids).to include(s1.id, s2.id)
      expect(ids).not_to include(deleted.id)
    end

    it 'by_status filters by status' do
      ids = Supplier.by_status('active').pluck(:id)
      expect(ids).to include(s1.id)
      expect(ids).not_to include(s2.id)
    end

    it 'search_query matches name' do
      ids = Supplier.search_query('Alpha').pluck(:id)
      expect(ids).to include(s1.id)
      expect(ids).not_to include(s2.id)
    end
  end
end
