require 'rails_helper'

RSpec.describe Beats::CreateBeatService, type: :service do
  let(:org)    { create(:organization) }
  let(:branch) { create(:branch, organization: org) }
  let(:actor)  { create(:user) }
  let(:route)  { create(:route, organization: org, branch: branch) }

  def call(overrides = {})
    described_class.new(
      params:       { name: 'Test Beat', code: 'TEST-001', route_id: route.id }.merge(overrides),
      actor:        actor,
      organization: org,
      branch_id:    branch.id
    ).call
  end

  it 'creates a beat and returns success' do
    expect { call }.to change(Beat, :count).by(1)
    expect(call.success?).to be true
  end

  it 'upcases the code' do
    result = call(code: 'lowercase')
    expect(result.beat.code).to eq('LOWERCASE')
  end

  it 'creates an audit log' do
    expect { call }.to change(AuditLog.where(action: 'beat_created'), :count).by(1)
  end

  it 'returns errors for duplicate code in same branch' do
    call
    result = call
    expect(result.success?).to be false
    expect(result.errors).not_to be_empty
  end

  it 'returns errors when name is missing' do
    result = call(name: '')
    expect(result.success?).to be false
  end
end
