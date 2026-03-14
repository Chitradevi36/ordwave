require 'rails_helper'

RSpec.describe BillingEvent, type: :model do
  subject(:event) { build(:billing_event) }

  # ── Associations ─────────────────────────────────────────────────────────────
  it { is_expected.to belong_to(:organization) }
  it { is_expected.to belong_to(:subscription).optional }

  # ── Validations ──────────────────────────────────────────────────────────────
  it { is_expected.to validate_presence_of(:event_type) }

  # ── Scopes ───────────────────────────────────────────────────────────────────
  describe ".for_type" do
    it "filters by event_type" do
      charged  = create(:billing_event, event_type: "subscription.charged")
      _failed  = create(:billing_event, :payment_failed)
      expect(BillingEvent.for_type("subscription.charged")).to contain_exactly(charged)
    end
  end

  # ── Idempotency ──────────────────────────────────────────────────────────────
  describe ".find_or_create_for_webhook" do
    let(:org)  { create(:organization) }
    let(:sub)  { create(:subscription, organization: org) }
    let(:args) do
      {
        organization:     org,
        subscription:     sub,
        event_type:       "subscription.charged",
        razorpay_event_id: "evt_test_123",
        payload:          { "foo" => "bar" }
      }
    end

    it "creates a new event on first call" do
      expect { described_class.find_or_create_for_webhook(**args) }
        .to change(BillingEvent, :count).by(1)
    end

    it "does NOT create a duplicate on subsequent calls with same razorpay_event_id" do
      described_class.find_or_create_for_webhook(**args)
      expect { described_class.find_or_create_for_webhook(**args) }
        .not_to change(BillingEvent, :count)
    end

    it "yields the event only when newly created" do
      yielded_events = []
      described_class.find_or_create_for_webhook(**args) { |e| yielded_events << e }
      described_class.find_or_create_for_webhook(**args) { |e| yielded_events << e }
      expect(yielded_events.size).to eq(1)
    end
  end

  # ── record_internal! ─────────────────────────────────────────────────────────
  describe ".record_internal!" do
    let(:org) { create(:organization) }

    it "creates an event with processed_at set" do
      event = described_class.record_internal!(
        organization: org,
        event_type:   "internal.free_plan_activated",
        payload:      { plan: "free" }
      )
      expect(event.processed_at).to be_present
      expect(event.razorpay_event_id).to be_nil
    end
  end

  # ── Instance helpers ─────────────────────────────────────────────────────────
  describe "#mark_processed!" do
    let(:event) { create(:billing_event, :unprocessed) }

    it "sets processed_at to current time" do
      expect { event.mark_processed! }
        .to change { event.reload.processed_at }.from(nil)
    end
  end
end
