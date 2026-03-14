require 'rails_helper'

RSpec.describe Subscription, type: :model do
  subject(:subscription) { build(:subscription) }

  # ── Validations ─────────────────────────────────────────────────────────────
  describe "validations" do
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to have_many(:billing_events) }

    it { is_expected.to validate_presence_of(:plan) }
    it { is_expected.to validate_inclusion_of(:plan).in_array(Billing::PlanCatalog::PLANS) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_inclusion_of(:status).in_array(Subscription::STATUSES) }
  end

  # ── Scopes ──────────────────────────────────────────────────────────────────
  describe ".active" do
    it "returns only active subscriptions" do
      active_sub  = create(:subscription, :active)
      _past_due   = create(:subscription, :past_due, organization: active_sub.organization)
      expect(Subscription.active).to contain_exactly(active_sub)
    end
  end

  describe ".current" do
    it "returns active and past_due subscriptions" do
      org     = create(:organization)
      active  = create(:subscription, :active,   organization: org)
      past_d  = create(:subscription, :past_due, organization: org)
      _expired = create(:subscription, :expired,  organization: org)
      expect(Subscription.current).to include(active, past_d)
    end
  end

  # ── State predicate helpers ──────────────────────────────────────────────────
  describe "#active?" do
    it "returns true when status is active"  do
      expect(build(:subscription, :active)).to be_active
    end

    it "returns false for other statuses" do
      expect(build(:subscription, :pending)).not_to be_active
    end
  end

  describe "#free?" do
    it "returns true for free plan" do
      expect(build(:subscription, :free)).to be_free
    end

    it "returns false for paid plans" do
      expect(build(:subscription, :starter)).not_to be_free
    end
  end

  # ── State transitions ────────────────────────────────────────────────────────
  describe "#activate!" do
    let(:sub) { create(:subscription, :pending) }

    it "sets status to active and updates period dates" do
      period_end = 1.month.from_now
      sub.activate!(period_end: period_end)

      expect(sub.reload).to be_active
      expect(sub.current_period_end).to be_within(1.second).of(period_end)
    end
  end

  describe "#mark_past_due!" do
    let(:sub) { create(:subscription, :active) }

    it "sets status to past_due and sets ends_at" do
      sub.mark_past_due!
      expect(sub.reload).to be_past_due
      expect(sub.ends_at).to be > Time.current
    end
  end

  describe "#cancel!" do
    let(:sub) { create(:subscription, :active) }

    it "sets status to cancelled and records cancelled_at" do
      sub.cancel!
      expect(sub.reload).to be_cancelled
      expect(sub.cancelled_at).to be_present
    end
  end
end
