require 'rails_helper'

RSpec.describe Visits::CheckinService, type: :service do
  let(:org)      { create(:organization) }
  let(:branch)   { create(:branch, organization: org) }
  let(:sales_rep) { create(:user) }
  let(:customer)  { create(:customer, organization: org, branch: branch) }

  def call(overrides = {})
    described_class.new(
      params: {
        customer_id:     customer.id,
        visit_date:      Date.current.iso8601,
        idempotency_key: SecureRandom.uuid
      }.merge(overrides),
      actor:        sales_rep,
      organization: org,
      branch:       branch
    ).call
  end

  it 'creates a visit log with status checked_in' do
    expect { call }.to change(VisitLog, :count).by(1)
    result = call
    expect(result.success?).to be true
  end

  it 'returns the existing log on duplicate idempotency_key (idempotency)' do
    key = SecureRandom.uuid
    first  = call(idempotency_key: key)
    second = call(idempotency_key: key)
    expect(first.visit_log.id).to eq(second.visit_log.id)
  end

  it 'creates an audit log' do
    expect { call }.to change(AuditLog.where(action: 'visit_checked_in'), :count).by(1)
  end

  it 'returns errors for missing customer_id' do
    result = call(customer_id: nil)
    expect(result.success?).to be false
  end
end
