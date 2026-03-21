require 'rails_helper'

describe 'Api::V1::PaymentsController - Auto-Posting Endpoints' do
  let(:user) { create(:user, role: :finance_manager) }
  let(:organization) { user.organization }
  let(:customer) { create(:customer, organization: organization) }
  let(:branch) { organization.branches.first }
  let(:invoice) { create(:invoice, customer: customer, branch: branch) }

  before do
    sign_in user
  end

  describe 'GET /api/v1/payments/auto_posting_status' do
    it 'returns auto-posting configuration and statistics' do
      get :auto_posting_status, as: :json, format: :json, params: { organization_id: organization.id }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json['auto_posting_enabled']).to be true
      expect(json['confidence_threshold_auto']).to eq(95)
      expect(json['confidence_threshold_suggest']).to eq(85)
      expect(json['rejection_window_minutes']).to eq(60)
      expect(json).to have_key('stats')
      expect(json).to have_key('configuration')
    end

    it 'includes today statistics' do
      # Create some auto-posted payments
      payment = create(:payment, auto_posted: true)
      AutoPostAudit.create!(
        payment: payment,
        action: 'auto_posted',
        timestamp: Time.current
      )

      get :auto_posting_status, as: :json, format: :json, params: { organization_id: organization.id }

      json = JSON.parse(response.body)
      expect(json['stats']['today_auto_posted']).to be >= 1
    end

    it 'does not require authorization' do
      sign_out user
      get :auto_posting_status, as: :json, format: :json, params: { organization_id: organization.id }
      expect(response).to have_http_status(:success)
    end
  end

  describe 'POST /api/v1/payments/:id/reject_auto_post' do
    let(:payment) do
      create(:payment,
        auto_posted: true,
        rejection_window_expires_at: 1.hour.from_now,
        customer: customer,
        organization: organization
      )
    end

    before do
      # Create allocation so invoice gets reverted
      create(:payment_allocation,
        payment: payment,
        sales_invoice: invoice,
        allocated_amount: payment.amount
      )
    end

    it 'rejects an auto-posted payment within window' do
      post :reject_auto_post,
        params: {
          id: payment.id,
          rejection_reason: 'Customer name mismatch',
          organization_id: organization.id
        },
        as: :json,
        format: :json

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json['ok']).to be true
      expect(json['message']).to include('reversed')

      payment.reload
      expect(payment.reversed?).to be true
      expect(payment.reversal_reason).to eq('Customer name mismatch')
    end

    it 'returns 422 if window expired' do
      payment.update!(rejection_window_expires_at: 1.hour.ago)

      post :reject_auto_post,
        params: {
          id: payment.id,
          rejection_reason: 'Too late',
          organization_id: organization.id
        },
        as: :json,
        format: :json

      expect(response).to have_http_status(422)
      json = JSON.parse(response.body)
      expect(json['ok']).to be false
      expect(json['error']).to include('expired')
    end

    it 'returns 422 if payment not auto-posted' do
      manual_payment = create(:payment,
        auto_posted: false,
        customer: customer,
        organization: organization
      )

      post :reject_auto_post,
        params: {
          id: manual_payment.id,
          rejection_reason: 'Not auto-posted',
          organization_id: organization.id
        },
        as: :json,
        format: :json

      expect(response).to have_http_status(422)
      json = JSON.parse(response.body)
      expect(json['ok']).to be false
    end

    it 'returns 404 if payment not found' do
      post :reject_auto_post,
        params: {
          id: 99999,
          rejection_reason: 'Not found',
          organization_id: organization.id
        },
        as: :json,
        format: :json

      expect(response).to have_http_status(404)
    end

    it 'requires finance role' do
      basic_user = create(:user, role: :sales)
      sign_in basic_user

      post :reject_auto_post,
        params: {
          id: payment.id,
          rejection_reason: 'Unauthorized',
          organization_id: basic_user.organization.id
        },
        as: :json,
        format: :json

      expect(response).to have_http_status(401)
    end

    it 'logs audit trail with actor' do
      post :reject_auto_post,
        params: {
          id: payment.id,
          rejection_reason: 'Finance review',
          organization_id: organization.id
        },
        as: :json,
        format: :json

      audit = AutoPostAudit.find_by(payment: payment, action: 'rejected_by_finance')
      expect(audit).to be_present
      expect(audit.actor_id).to eq(user.id)
    end
  end

  describe 'GET /api/v1/payments/:id/confidence_breakdown' do
    let(:payment) do
      create(:payment,
        auto_posted: true,
        confidence_score: 96.5,
        customer: customer,
        organization: organization
      )
    end

    before do
      AutoPostAudit.create!(
        payment: payment,
        action: 'auto_posted',
        confidence_breakdown: {
          amount: 30,
          date: 20,
          customer: 25,
          reference: 15,
          history: 6.5
        },
        timestamp: Time.current
      )
    end

    it 'returns confidence score breakdown' do
      get :confidence_breakdown,
        params: { id: payment.id, organization_id: organization.id },
        as: :json,
        format: :json

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json['payment_id']).to eq(payment.id)
      expect(json['confidence_score']).to eq(96.5)
      expect(json['confidence_grade']).to eq('high')
      expect(json['auto_posted']).to be true
      expect(json).to have_key('can_reject_until')
      expect(json).to have_key('time_until_expires_seconds')
    end

    it 'returns 404 if payment not found' do
      get :confidence_breakdown,
        params: { id: 99999, organization_id: organization.id },
        as: :json,
        format: :json

      expect(response).to have_http_status(404)
    end

    it 'returns 404 if payment not auto-posted' do
      manual_payment = create(:payment,
        auto_posted: false,
        customer: customer,
        organization: organization
      )

      get :confidence_breakdown,
        params: { id: manual_payment.id, organization_id: organization.id },
        as: :json,
        format: :json

      expect(response).to have_http_status(404)
    end
  end

  describe 'GET /api/v1/payments/audit_trail' do
    before do
      # Create several audit records
      payment1 = create(:payment, auto_posted: true)
      payment2 = create(:payment, auto_posted: true)

      AutoPostAudit.create!(
        payment: payment1,
        action: 'auto_posted',
        timestamp: Time.current,
        audit_notes: 'High confidence match'
      )

      AutoPostAudit.create!(
        payment: payment2,
        action: 'rejected_by_finance',
        timestamp: 2.hours.ago,
        audit_notes: 'Name mismatch'
      )
    end

    it 'returns audit trail with pagination' do
      get :audit_trail,
        params: {
          organization_id: organization.id,
          limit: 50,
          offset: 0
        },
        as: :json,
        format: :json

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to have_key('audits')
      expect(json).to have_key('total')
      expect(json).to have_key('page')
      expect(json).to have_key('per_page')
      expect(json).to have_key('pages')
      expect(json['audits']).to be_an(Array)
    end

    it 'filters by action' do
      get :audit_trail,
        params: {
          organization_id: organization.id,
          filters: { action: 'auto_posted' }
        },
        as: :json,
        format: :json

      json = JSON.parse(response.body)
      expect(json['audits'].all? { |a| a['action'] == 'auto_posted' }).to be true
    end

    it 'filters by status (auto_posted)' do
      get :audit_trail,
        params: {
          organization_id: organization.id,
          filters: { status: 'auto_posted' }
        },
        as: :json,
        format: :json

      json = JSON.parse(response.body)
      expect(json['audits'].size).to be >= 1
    end

    it 'filters by status (rejected)' do
      get :audit_trail,
        params: {
          organization_id: organization.id,
          filters: { status: 'rejected' }
        },
        as: :json,
        format: :json

      json = JSON.parse(response.body)
      expect(json['audits'].all? { |a| a['action'].start_with?('rejected') }).to be true
    end

    it 'filters by date range' do
      from_date = 1.day.ago.to_date
      to_date = Date.today

      get :audit_trail,
        params: {
          organization_id: organization.id,
          filters: {
            date_from: from_date.to_s,
            date_to: to_date.to_s
          }
        },
        as: :json,
        format: :json

      expect(response).to have_http_status(:success)
    end

    it 'supports pagination' do
      get :audit_trail,
        params: {
          organization_id: organization.id,
          limit: 1,
          offset: 0
        },
        as: :json,
        format: :json

      json = JSON.parse(response.body)
      expect(json['per_page']).to eq(1)
      expect(json['audits'].size).to be <= 1
    end
  end

  describe 'GET /api/v1/payments/auto_post_stats' do
    before do
      # Create some statistics
      payment = create(:payment, auto_posted: true)
      AutoPostAudit.create!(
        payment: payment,
        action: 'auto_posted',
        timestamp: Time.current
      )

      RejectionFeedback.create!(
        payment: payment,
        confidence_score: 92.0,
        rejection_reason: 'Amount mismatch',
        timestamp: Time.current
      )
    end

    it 'returns auto-posting statistics' do
      get :auto_post_stats,
        params: { organization_id: organization.id },
        as: :json,
        format: :json

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to have_key('period')
      expect(json).to have_key('date_range')
      expect(json).to have_key('total_transactions')
      expect(json).to have_key('auto_posted')
      expect(json).to have_key('rejected')
      expect(json).to have_key('success_rate')
    end

    it 'supports period parameter (today)' do
      get :auto_post_stats,
        params: { organization_id: organization.id, period: 'today' },
        as: :json,
        format: :json

      json = JSON.parse(response.body)
      expect(json['period']).to eq('today')
    end

    it 'supports period parameter (week)' do
      get :auto_post_stats,
        params: { organization_id: organization.id, period: 'week' },
        as: :json,
        format: :json

      json = JSON.parse(response.body)
      expect(json['period']).to eq('week')
    end

    it 'calculates success rate correctly' do
      # Setup: 2 auto-posted, 0 rejected
      get :auto_post_stats,
        params: { organization_id: organization.id, period: 'today' },
        as: :json,
        format: :json

      json = JSON.parse(response.body)
      if json['total_transactions'] > 0
        expected_rate = (json['auto_posted'].to_f / json['total_transactions'] * 100).round(2)
        expect(json['success_rate']).to equal(expected_rate)
      end
    end

    it 'includes rejection reasons' do
      get :auto_post_stats,
        params: { organization_id: organization.id, period: 'today' },
        as: :json,
        format: :json

      json = JSON.parse(response.body)
      expect(json).to have_key('rejection_reasons')
    end
  end

  describe 'Authorization Tests' do
    let(:payment) do
      create(:payment,
        auto_posted: true,
        rejection_window_expires_at: 1.hour.from_now,
        customer: customer,
        organization: organization
      )
    end

    it 'blocks non-finance users from rejection' do
      sales_user = create(:user, role: :sales, organization: organization)
      sign_in sales_user

      post :reject_auto_post,
        params: {
          id: payment.id,
          rejection_reason: 'Unauthorized',
          organization_id: organization.id
        },
        as: :json,
        format: :json

      expect(response).to have_http_status(401)
    end

    it 'allows admin users to reject' do
      admin = create(:user, role: :admin, organization: organization)
      sign_in admin

      post :reject_auto_post,
        params: {
          id: payment.id,
          rejection_reason: 'Admin override',
          organization_id: organization.id
        },
        as: :json,
        format: :json

      expect(response).to have_http_status(:success)
    end

    it 'blocks unauthenticated access to rejection' do
      sign_out user

      post :reject_auto_post,
        params: {
          id: payment.id,
          rejection_reason: 'Not logged in',
          organization_id: organization.id
        },
        as: :json,
        format: :json

      expect(response).to have_http_status(401)
    end
  end

  describe 'Response Format' do
    it 'returns JSON responses' do
      get :auto_posting_status,
        params: { organization_id: organization.id },
        as: :json,
        format: :json

      expect(response.content_type).to include('application/json')
    end

    it 'includes proper HTTP status codes' do
      payment = create(:payment, auto_posted: false, customer: customer, organization: organization)

      get :confidence_breakdown,
        params: { id: payment.id, organization_id: organization.id },
        as: :json,
        format: :json

      expect(response).to have_http_status(404)
    end

    it 'handles error responses gracefully' do
      post :reject_auto_post,
        params: {
          id: 99999,
          rejection_reason: 'err',
          organization_id: organization.id
        },
        as: :json,
        format: :json

      expect(response).to have_http_status(404)
      json = JSON.parse(response.body)
      expect(json).to have_key('error')
    end
  end
end
