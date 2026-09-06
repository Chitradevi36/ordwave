require 'rails_helper'

RSpec.describe Billing::FoundingDistributorProgramService do
  let(:organization) { create(:organization) }

  describe '#call' do
    it 'creates a founding subscription with pricing metadata when spots remain' do
      result = described_class.new(organization: organization, now: Time.zone.parse('2026-09-06 10:00:00')).call

      expect(result.success?).to eq(true)
      expect(result.eligible).to eq(true)
      expect(result.claimed).to eq(true)
      expect(result.remaining_spots).to eq(9)
      expect(result.founding_subscription).to be_present
      expect(result.founding_subscription.plan).to eq('growth')
      expect(result.founding_subscription.metadata['pricing_variant']).to eq('founding')
      expect(result.founding_subscription.metadata['founding_start_date']).to eq('2026-09-06T10:00:00')
      expect(result.founding_subscription.metadata['founding_end_date']).to eq('2027-09-06T10:00:00')
    end

    it 'blocks new claims after capacity is reached' do
      create_list(:subscription, 10, :pending, :active, plan: 'growth', metadata: { 'pricing_variant' => 'founding' })

      result = described_class.new(organization: organization).call

      expect(result.success?).to eq(false)
      expect(result.errors).to include('Founding program is full')
    end
  end
end
