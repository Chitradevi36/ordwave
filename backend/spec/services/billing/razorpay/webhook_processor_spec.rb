require 'rails_helper'

RSpec.describe Billing::Razorpay::WebhookProcessor do
  let(:org)          { create(:organization) }
  let(:subscription) { create(:subscription, :pending, organization: org, razorpay_subscription_id: "sub_test123") }

  let(:base_payload) do
    {
      "id"    => SecureRandom.hex(8),
      "event" => "subscription.charged",
      "payload" => {
        "subscription" => {
          "entity" => {
            "id"            => subscription.razorpay_subscription_id,
            "current_start" => 1.day.ago.to_i,
            "current_end"   => 29.days.from_now.to_i,
            "notes"         => { "organization_id" => org.id.to_s }
          }
        },
        "payment" => {
          "entity" => {
            "id"       => "pay_test_001",
            "amount"   => 149_900,
            "currency" => "INR"
          }
        }
      }
    }
  end

  subject(:processor) do
    described_class.new(
      raw_body:  base_payload.to_json,
      signature: valid_signature(base_payload.to_json),
      payload:   base_payload
    )
  end

  def valid_signature(body)
    # In test env, webhook secret is blank so signature check is bypassed
    ""
  end

  before do
    # Ensure subscription exists so the processor can find it
    subscription
    # Stub RAZORPAY_WEBHOOK_SECRET to blank (bypassed in test)
    stub_const("Billing::RAZORPAY_WEBHOOK_SECRET", "")
  end

  # ── Signature validation ────────────────────────────────────────────────────
  describe "signature verification" do
    context "when webhook secret IS configured" do
      before { stub_const("Billing::RAZORPAY_WEBHOOK_SECRET", "test_secret") }

      it "rejects requests with invalid signature" do
        processor = described_class.new(
          raw_body:  base_payload.to_json,
          signature: "bad_signature",
          payload:   base_payload
        )
        result = processor.call
        expect(result.success?).to be false
        expect(result.error).to match(/Invalid signature/)
      end
    end

    context "when webhook secret is blank (test mode)" do
      it "skips signature check and processes the event" do
        result = processor.call
        expect(result.success?).to be true
      end
    end
  end

  # ── Event processing ────────────────────────────────────────────────────────
  describe "#call" do
    context "with a valid subscription.charged event" do
      it "returns success" do
        expect(processor.call.success?).to be true
      end

      it "creates a BillingEvent record" do
        expect { processor.call }.to change(BillingEvent, :count).by(1)
      end

      it "activates the subscription" do
        processor.call
        expect(subscription.reload).to be_active
      end

      it "sets billing_status on the organization to active" do
        processor.call
        expect(org.reload.billing_status).to eq("active")
      end
    end

    context "with a duplicate event (same razorpay_event_id)" do
      it "skips processing without error" do
        processor.call
        duplicate_result = processor.call
        expect(duplicate_result.success?).to be true
        expect(duplicate_result.skipped).to be true
      end

      it "does not create duplicate BillingEvent records" do
        processor.call
        expect { processor.call }.not_to change(BillingEvent, :count)
      end
    end

    context "with an unsupported event type" do
      let(:unsupported_payload) { base_payload.merge("event" => "order.paid") }

      subject(:processor) do
        described_class.new(
          raw_body:  unsupported_payload.to_json,
          signature: "",
          payload:   unsupported_payload
        )
      end

      it "returns success with skipped: true" do
        result = processor.call
        expect(result.success?).to be true
        expect(result.skipped).to be true
      end
    end

    context "with a payment.failed event" do
      let(:active_sub) { create(:subscription, :active, organization: org, razorpay_subscription_id: "sub_active_001") }
      let(:failed_payload) do
        {
          "id"    => SecureRandom.hex(8),
          "event" => "payment.failed",
          "payload" => {
            "subscription" => {
              "entity" => {
                "id"    => active_sub.razorpay_subscription_id,
                "notes" => { "organization_id" => org.id.to_s }
              }
            },
            "payment" => { "entity" => { "error_code" => "BAD_REQUEST_ERROR" } }
          }
        }
      end

      before { active_sub }

      it "marks subscription as past_due" do
        described_class.new(
          raw_body:  failed_payload.to_json,
          signature: "",
          payload:   failed_payload
        ).call
        expect(active_sub.reload).to be_past_due
      end

      it "sets org billing_status to past_due" do
        described_class.new(
          raw_body:  failed_payload.to_json,
          signature: "",
          payload:   failed_payload
        ).call
        expect(org.reload.billing_status).to eq("past_due")
      end
    end
  end
end
