require 'rails_helper'

RSpec.describe Organization, type: :model do
  describe 'validations' do
    subject { create(:organization) }

    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:plan) }
    it { should validate_inclusion_of(:plan).in_array(User::PLANS) }
    it { should validate_uniqueness_of(:slug).case_insensitive }

    it 'validates GST number format' do
      org = build(:organization, gst_number: 'invalid')
      expect(org).not_to be_valid
      expect(org.errors[:gst_number]).to include('is invalid')
    end

    it 'allows valid GST number' do
      org = build(:organization, gst_number: '29ABCDE1234F1Z5')
      expect(org).to be_valid
    end

    it 'allows nil GST number' do
      org = build(:organization, gst_number: nil)
      expect(org).to be_valid
    end
  end

  describe 'associations' do
    it { should have_many(:branches).dependent(:destroy) }
    it { should have_many(:memberships).dependent(:destroy) }
    it { should have_many(:users).through(:memberships) }
    it { should have_many(:onboarding_progresses).dependent(:destroy) }
  end

  describe 'slug generation' do
    it 'generates slug from name before creation' do
      org = create(:organization, name: 'Test Company Ltd')
      expect(org.slug).to match(/^test-company-ltd/)
    end

    it 'appends random string for uniqueness' do
      create(:organization, name: 'Test Org', slug: 'test-org-abc')
      org = create(:organization, name: 'Test Org')
      expect(org.slug).to match(/^test-org-[a-z0-9]{6}$/)
    end
  end
end
