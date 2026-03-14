require 'rails_helper'

RSpec.describe 'Api::V1::Billing', type: :request do
  # ── Shared setup ────────────────────────────────────────────────────────────
  let(:owner_role) { create(:role, name: 'owner') }
  let(:org)        { create(:organization, plan: "starter", billing_status: "active") }
  let(:branch)     { create(:branch, organization: org) }
  let(:owner)      { create(:user, plan: "starter") }
  let!(:owner_membership) do
    create(:membership, user: owner, organization: org, branch: branch, role: owner_role)
  end
  let!(:active_sub) { create(:subscription, :active, :starter, organization: org) }

  def generate_jwt_for(user)
    payload = { sub: user.id, email: user.email, jti: SecureRandom.uuid, exp: 24.hours.from_now.to_i }
    JWT.encode(payload, Rails.application.secret_key_base, 'HS256')
  end

  def auth_headers(user = owner)
    {
      'Authorization'     => "Bearer #{generate_jwt_for(user)}",
      'X-Organization-Id' => org.id.to_s
    }
  end

  def json_body
    JSON.parse(response.body)
  end

  # ── GET /api/v1/billing/subscription ────────────────────────────────────────
  describe 'GET /api/v1/billing/subscription' do
    context 'when authenticated' do
      it 'returns subscription data and plan details' do
        get '/api/v1/billing/subscription', headers: auth_headers
        expect(response).to have_http_status(:ok)
        data = json_body['data']
        expect(data['plan']).to eq('starter')
        expect(data['billing_status']).to eq('active')
        expect(data['subscription']['status']).to eq('active')
      end

      it 'returns plan limits in usage_summary' do
        get '/api/v1/billing/subscription', headers: auth_headers
        summary = json_body['data']['usage_summary']
        expect(summary['plan']).to eq('starter')
        expect(summary['max_branches']).to eq(3)
      end

      it 'returns all plans for display' do
        get '/api/v1/billing/subscription', headers: auth_headers
        plans = json_body['data']['all_plans']
        expect(plans.map { |p| p['plan'] }).to match_array(%w[free starter pro])
      end
    end

    context 'without authentication' do
      it 'returns 401' do
        get '/api/v1/billing/subscription'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ── POST /api/v1/billing/checkout ────────────────────────────────────────────
  describe 'POST /api/v1/billing/checkout' do
    context 'with free plan' do
      it 'returns an error (free plan does not require payment)' do
        post '/api/v1/billing/checkout', params: { plan: 'free' }, headers: auth_headers
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_body['errors']).to be_present
      end
    end

    context 'with a paid plan' do
      before do
        # Stub the SubscriptionCreator service
        allow(Billing::Razorpay::SubscriptionCreator).to receive(:new).and_return(
          instance_double(
            Billing::Razorpay::SubscriptionCreator,
            call: Billing::Razorpay::SubscriptionCreator::Result.new(
              success?:     true,
              subscription: active_sub,
              short_url:    "https://rzp.io/l/testlink",
              error:        nil
            )
          )
        )
      end

      it 'returns a short_url for the Razorpay hosted page' do
        post '/api/v1/billing/checkout', params: { plan: 'pro' }, headers: auth_headers
        expect(response).to have_http_status(:created)
        expect(json_body['data']['short_url']).to be_present
      end
    end

    context 'when Razorpay returns an error' do
      before do
        allow(Billing::Razorpay::SubscriptionCreator).to receive(:new).and_return(
          instance_double(
            Billing::Razorpay::SubscriptionCreator,
            call: Billing::Razorpay::SubscriptionCreator::Result.new(
              success?:     false,
              subscription: nil,
              short_url:    nil,
              error:        "RAZORPAY_PLAN_ID_PRO_MONTHLY is not configured"
            )
          )
        )
      end

      it 'returns 422 with error message' do
        post '/api/v1/billing/checkout', params: { plan: 'pro' }, headers: auth_headers
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_body['errors'].first).to match(/not configured/)
      end
    end
  end

  # ── POST /api/v1/billing/cancel ──────────────────────────────────────────────
  describe 'POST /api/v1/billing/cancel' do
    context 'when owner cancels' do
      before do
        allow(::Razorpay::Subscription).to receive(:cancel).and_return(true)
      end

      it 'cancels the subscription and returns 200' do
        post '/api/v1/billing/cancel', headers: auth_headers
        expect(response).to have_http_status(:ok)
        expect(active_sub.reload).to be_cancelled
        expect(org.reload.billing_status).to eq('cancelled')
      end
    end

    context 'when non-owner tries to cancel' do
      let(:member_role) { create(:role, name: 'manager') }
      let(:member_user) { create(:user) }
      let!(:member_membership) do
        create(:membership, user: member_user, organization: org, branch: branch, role: member_role)
      end

      it 'returns 403 forbidden' do
        post '/api/v1/billing/cancel', headers: auth_headers(member_user)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when there is no active subscription' do
      before { active_sub.update!(status: 'cancelled') }

      it 'returns 422' do
        post '/api/v1/billing/cancel', headers: auth_headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  # ── GET /api/v1/billing/invoices ─────────────────────────────────────────────
  describe 'GET /api/v1/billing/invoices' do
    let!(:charged_event) { create(:billing_event, organization: org, subscription: active_sub, event_type: 'subscription.charged') }
    let!(:failed_event)  { create(:billing_event, :payment_failed, organization: org, subscription: active_sub) }

    it 'returns billing events' do
      get '/api/v1/billing/invoices', headers: auth_headers
      expect(response).to have_http_status(:ok)
      events = json_body['data']
      expect(events.size).to eq(2)
      expect(events.map { |e| e['event_type'] }).to include('subscription.charged', 'payment.failed')
    end
  end

  # ── POST /api/v1/billing/webhooks/razorpay ───────────────────────────────────
  describe 'POST /api/v1/billing/webhooks/razorpay' do
    let(:org_with_sub) { create(:organization, billing_status: 'inactive') }
    let(:pending_sub)  { create(:subscription, :pending, :starter, organization: org_with_sub, razorpay_subscription_id: 'sub_webhook_001') }

    let(:webhook_payload) do
      {
        "id"    => SecureRandom.hex(8),
        "event" => "subscription.charged",
        "payload" => {
          "subscription" => {
            "entity" => {
              "id"            => pending_sub.razorpay_subscription_id,
              "current_start" => 1.day.ago.to_i,
              "current_end"   => 29.days.from_now.to_i,
              "notes"         => { "organization_id" => org_with_sub.id.to_s }
            }
          },
          "payment" => { "entity" => { "id" => "pay_001", "amount" => 149_900 } }
        }
      }
    end

    before do
      pending_sub  # ensure it's created
      stub_const("Billing::RAZORPAY_WEBHOOK_SECRET", "")  # bypass sig check in tests
    end

    it 'processes a valid webhook and returns 200' do
      post '/api/v1/billing/webhooks/razorpay',
           params:  webhook_payload.to_json,
           headers: { 'Content-Type' => 'application/json', 'X-Razorpay-Signature' => '' }
      expect(response).to have_http_status(:ok)
      expect(json_body['status']).to eq('ok')
    end

    it 'activates the organization billing_status' do
      post '/api/v1/billing/webhooks/razorpay',
           params:  webhook_payload.to_json,
           headers: { 'Content-Type' => 'application/json', 'X-Razorpay-Signature' => '' }
      expect(org_with_sub.reload.billing_status).to eq('active')
    end

    it 'returns 200 for duplicate webhook (idempotent)' do
      2.times do
        post '/api/v1/billing/webhooks/razorpay',
             params:  webhook_payload.to_json,
             headers: { 'Content-Type' => 'application/json', 'X-Razorpay-Signature' => '' }
        expect(response).to have_http_status(:ok)
      end
    end

    it 'returns 400 for malformed JSON' do
      post '/api/v1/billing/webhooks/razorpay',
           params:  "not valid json",
           headers: { 'Content-Type' => 'application/json', 'X-Razorpay-Signature' => '' }
      expect(response).to have_http_status(:bad_request)
    end
  end
end
