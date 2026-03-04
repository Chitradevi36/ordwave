require 'rails_helper'

RSpec.describe Route, type: :model do
  let(:org)    { create(:organization) }
  let(:branch) { create(:branch, organization: org) }

  describe 'validations' do
    subject { create(:route, organization: org, branch: branch) }

    it { should validate_presence_of(:name) }

    it 'validates code uniqueness within branch' do
      create(:route, organization: org, branch: branch, code: 'RT-001')
      dup = build(:route, organization: org, branch: branch, code: 'RT-001')
      expect(dup).not_to be_valid
    end

    it 'allows same code in different branches' do
      b2 = create(:branch, organization: org)
      create(:route, organization: org, branch: branch, code: 'RT-001')
      dup = build(:route, organization: org, branch: b2, code: 'RT-001')
      expect(dup).to be_valid
    end

    it 'validates code format (uppercase alphanumeric with dashes)' do
      r = build(:route, organization: org, branch: branch, code: 'rt 001')
      expect(r).not_to be_valid
    end
  end

  describe 'associations' do
    it { should belong_to(:organization) }
    it { should belong_to(:branch) }
    it { should have_many(:customers).dependent(:nullify) }
  end

  describe 'scopes' do
    let!(:active_route)   { create(:route, organization: org, branch: branch, active: true) }
    let!(:inactive_route) { create(:route, organization: org, branch: branch, active: false) }

    it '.active returns only active routes' do
      expect(Route.active).to include(active_route)
      expect(Route.active).not_to include(inactive_route)
    end

    it '.for_org filters by organization_id' do
      org2 = create(:organization)
      b2   = create(:branch, organization: org2)
      r2   = create(:route, organization: org2, branch: b2)
      expect(Route.for_org(org.id)).to include(active_route)
      expect(Route.for_org(org.id)).not_to include(r2)
    end
  end
end
