require 'rails_helper'

RSpec.describe Visits::GetTodaysPlanService, type: :service do
  let(:org)      { create(:organization) }
  let(:branch)   { create(:branch, organization: org) }
  let(:sales_rep) { create(:user) }
  let(:route)    { create(:route, organization: org, branch: branch, active: true) }

  # Monday is ISO weekday 0 in our convention
  let(:monday) { Date.current.beginning_of_week(:monday) }

  def call(date: monday)
    described_class.new(
      sales_rep: sales_rep,
      branch:    branch,
      date:      date
    ).call
  end

  context 'when no schedules exist' do
    it 'returns success with an empty plan' do
      result = call
      expect(result.success?).to be true
      expect(result.plan).to be_empty
    end
  end

  context 'when a schedule exists for the given weekday' do
    let!(:beat)     { create(:beat, organization: org, branch: branch, route: route) }
    let!(:schedule) { create(:beat_schedule, organization: org, branch: branch, beat: beat, sales_rep: sales_rep, weekday: 0, active: true) }
    let!(:customer) { create(:customer, organization: org, branch: branch, route: route, status: 'active', visit_frequency: 'weekly') }

    it 'includes the schedule in the plan' do
      result = call(date: monday)
      expect(result.plan).not_to be_empty
      expect(result.plan.first[:schedule].id).to eq(schedule.id)
    end

    it 'flags the customer as due if never visited' do
      result   = call(date: monday)
      customer_entry = result.plan.first[:customers].find { |c| c[:customer].id == customer.id }
      expect(customer_entry[:due]).to be true
      expect(customer_entry[:due_reason]).to eq('never_visited')
    end

    it 'flags the customer as not due if visited recently' do
      customer.update!(last_visited_at: Time.current - 1.day, next_due_on: Date.current + 6.days)
      result         = call(date: monday)
      customer_entry = result.plan.first[:customers].find { |c| c[:customer].id == customer.id }
      expect(customer_entry[:due]).to be false
    end
  end

  context 'with force_exclude override' do
    let!(:beat)     { create(:beat, organization: org, branch: branch, route: route) }
    let!(:schedule) { create(:beat_schedule, organization: org, branch: branch, beat: beat, sales_rep: sales_rep, weekday: 0, active: true) }
    let!(:customer) { create(:customer, organization: org, branch: branch, route: route, status: 'active', visit_frequency: 'daily') }
    let!(:br)       { create(:beat_retailer, beat_schedule: schedule, customer: customer, visit_override: 'force_exclude') }

    it 'excludes force_excluded customers' do
      result = call(date: monday)
      entries = result.plan.first[:customers]
      expect(entries.none? { |c| c[:customer].id == customer.id }).to be true
    end
  end
end
