require 'rails_helper'

RSpec.describe BeatPolicy, type: :policy do
  let(:org)    { create(:organization) }
  let(:branch) { create(:branch, organization: org) }

  let(:owner_role)    { create(:role, name: 'owner') }
  let(:admin_role)    { create(:role, name: 'admin') }
  let(:manager_role)  { create(:role, name: 'manager') }
  let(:member_role)   { create(:role, name: 'member') }

  def make_context(role)
    user = create(:user)
    create(:membership, user: user, organization: org, branch: branch, role: role)
    UserContext.new(user: user, organization: org)
  end

  def make_beat
    create(:beat, organization: org, branch: branch)
  end

  def policy(ctx, beat)
    described_class.new(ctx, beat)
  end

  describe '#index? / #show?' do
    let(:beat) { make_beat }

    it 'permits owner'   do expect(policy(make_context(owner_role),   beat)).to be_index; end
    it 'permits admin'   do expect(policy(make_context(admin_role),   beat)).to be_index; end
    it 'permits manager' do expect(policy(make_context(manager_role), beat)).to be_index; end
    it 'permits member'  do expect(policy(make_context(member_role),  beat)).to be_index; end

    it 'denies user with no membership' do
      user = create(:user)
      ctx  = UserContext.new(user: user, organization: org)
      expect(policy(ctx, beat)).not_to be_index
    end
  end

  describe '#create? / #update?' do
    let(:beat) { make_beat }

    it 'permits owner'   do expect(policy(make_context(owner_role),   beat)).to be_create; end
    it 'permits admin'   do expect(policy(make_context(admin_role),   beat)).to be_create; end
    it 'permits manager' do expect(policy(make_context(manager_role), beat)).to be_create; end
    it 'denies member'   do expect(policy(make_context(member_role),  beat)).not_to be_create; end
    it 'denies member on update' do
      expect(policy(make_context(member_role), beat)).not_to be_update
    end
  end

  describe 'Scope' do
    it 'returns active beats for the organization' do
      create(:beat, organization: org, branch: branch, active: true)
      create(:beat, organization: org, branch: branch, active: false)
      other_org = create(:organization)
      create(:beat, organization: other_org, branch: create(:branch, organization: other_org), active: true)

      ctx   = make_context(owner_role)
      scope = described_class::Scope.new(ctx, Beat.all).resolve
      expect(scope.count).to eq(1)
    end
  end
end
