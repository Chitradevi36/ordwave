require 'rails_helper'

RSpec.describe Subscription, type: :model do
  describe '#founding_growth?' do
    it 'detects founding growth subscriptions from metadata' do
      sub = build(:subscription, plan: 'growth', metadata: { 'pricing_variant' => 'founding' })

      expect(sub.founding_growth?).to eq(true)
    end
  end

  describe '#founding_end_date' do
    it 'parses the stored founding end date' do
      sub = build(:subscription, metadata: { 'founding_end_date' => '2027-09-06T10:00:00Z' })

      expect(sub.founding_end_date).to eq(Time.zone.parse('2027-09-06T10:00:00Z'))
    end
  end

  describe '#founding_expiring_soon?' do
    it 'flags founding subscriptions nearing expiration' do
      sub = build(
        :subscription,
        plan: 'growth',
        metadata: {
          'pricing_variant' => 'founding',
          'founding_end_date' => '2026-10-10T00:00:00Z'
        }
      )

      expect(sub.founding_expiring_soon?(Time.zone.parse('2026-09-06T00:00:00Z'))).to eq(true)
    end
  end
end
