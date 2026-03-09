# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::Accounting::AgentController, type: :controller do
  let(:organization) { create(:organization) }
  let(:integration) do
    create(:accounting_integration,
           organization: organization,
           provider: :tally,
           sync_mode: :realtime_agent,
           status: :connected)
  end
  let(:agent) do
    create(:accounting_agent,
           organization: organization,
           accounting_integration: integration)
  end
  let(:api_key) { agent.generate_api_key }

  before do
    agent.save!
  end

  # ─── POST /register ───────────────────────────────────────────────────────
  describe 'POST #register' do
    let(:valid_params) do
      {
        integration_id: integration.id,
        agent_version: '1.0.0',
        os_info: 'Windows 11',
        tally_version: 'TallyPrime 2.1'
      }
    end

    context 'when integration exists and is in realtime_agent mode' do
      it 'creates a new agent and returns API key' do
        expect {
          post :register, params: valid_params
        }.to change(AccountingAgent, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['agent_id']).to be_present
        expect(json['api_key']).to be_present
        expect(json['api_key']).to match(/^[a-f0-9]{64}$/)
      end

      it 'records agent version and system info' do
        post :register, params: valid_params

        new_agent = AccountingAgent.last
        expect(new_agent.agent_version).to eq('1.0.0')
        expect(new_agent.os_info).to eq('Windows 11')
        expect(new_agent.tally_version).to eq('TallyPrime 2.1')
      end
    end

    context 'when integration does not exist' do
      it 'returns 404' do
        post :register, params: { integration_id: 99999 }
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when integration is not in realtime_agent mode' do
      before do
        integration.update!(sync_mode: :batch_export)
      end

      it 'returns 422 unprocessable entity' do
        post :register, params: valid_params
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']).to include('realtime_agent')
      end
    end
  end

  # ─── POST /heartbeat ──────────────────────────────────────────────────────
  describe 'POST #heartbeat' do
    let(:auth_headers) { { 'Authorization' => "Bearer #{api_key}" } }

    context 'with valid authentication' do
      it 'updates last_heartbeat_at and returns success' do
        request.headers.merge!(auth_headers)

        Timecop.freeze do
          post :heartbeat
          expect(response).to have_http_status(:ok)

          agent.reload
          expect(agent.last_heartbeat_at).to be_within(1.second).of(Time.current)
          expect(agent.status).to eq('online')
        end
      end

      it 'updates agent version when provided' do
        request.headers.merge!(auth_headers)
        post :heartbeat, params: { agent_version: '1.1.0' }

        agent.reload
        expect(agent.agent_version).to eq('1.1.0')
      end

      it 'updates os_info and tally_version when provided' do
        request.headers.merge!(auth_headers)
        post :heartbeat, params: {
          os_info: 'Windows 10',
          tally_version: 'Tally.ERP 9'
        }

        agent.reload
        expect(agent.os_info).to eq('Windows 10')
        expect(agent.tally_version).to eq('Tally.ERP 9')
      end
    end

    context 'with invalid authentication' do
      it 'returns 401 unauthorized' do
        request.headers['Authorization'] = 'Bearer invalid_key'
        post :heartbeat
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'without authentication header' do
      it 'returns 401 unauthorized' do
        post :heartbeat
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ─── GET /poll ────────────────────────────────────────────────────────────
  describe 'GET #poll' do
    let(:auth_headers) { { 'Authorization' => "Bearer #{api_key}" } }
    let!(:pending_record) do
      create(:accounting_sync_record,
             organization: organization,
             accounting_integration: integration,
             status: 'pending',
             sync_type: 'voucher',
             source_model: 'SalesInvoice',
             source_id: 1,
             payload: { invoice_number: 'INV-001' }.to_json,
             response_body: '<VOUCHER><VOUCHERTYPENAME>Sales</VOUCHERTYPENAME></VOUCHER>')
    end

    before do
      request.headers.merge!(auth_headers)
    end

    context 'when pending records exist' do
      it 'returns pending records immediately' do
        get :poll

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['count']).to eq(1)
        expect(json['records']).to be_an(Array)
        expect(json['records'].first['id']).to eq(pending_record.id)
        expect(json['records'].first['xml_payload']).to include('<VOUCHER>')
      end

      it 'marks records as processing' do
        get :poll

        pending_record.reload
        expect(pending_record.status).to eq('processing')
        expect(pending_record.processing_started_at).to be_present
      end

      it 'respects limit parameter' do
        create_list(:accounting_sync_record, 15,
                    organization: organization,
                    accounting_integration: integration,
                    status: 'pending',
                    sync_type: 'voucher',
                    source_model: 'SalesInvoice',
                    response_body: '<VOUCHER></VOUCHER>')

        get :poll, params: { limit: 5 }

        json = JSON.parse(response.body)
        expect(json['count']).to eq(5)
      end

      it 'defaults to 10 records when limit not specified' do
        create_list(:accounting_sync_record, 15,
                    organization: organization,
                    accounting_integration: integration,
                    status: 'pending',
                    sync_type: 'voucher',
                    source_model: 'SalesInvoice',
                    response_body: '<VOUCHER></VOUCHER>')

        get :poll

        json = JSON.parse(response.body)
        expect(json['count']).to eq(10)
      end
    end

    context 'when no pending records exist' do
      before do
        pending_record.update!(status: 'completed')
      end

      it 'waits and returns empty array if no records arrive', :skip_long_running do
        # Note: This test would take 30 seconds in real execution
        # In practice, we'd mock the sleep behavior or reduce timeout for testing
        get :poll, params: { timeout: 1 }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['count']).to eq(0)
        expect(json['records']).to eq([])
      end
    end

    context 'with invalid authentication' do
      it 'returns 401 unauthorized' do
        request.headers['Authorization'] = 'Bearer invalid_key'
        get :poll
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ─── POST /ack/:id ────────────────────────────────────────────────────────
  describe 'POST #ack' do
    let(:auth_headers) { { 'Authorization' => "Bearer #{api_key}" } }
    let!(:processing_record) do
      create(:accounting_sync_record,
             organization: organization,
             accounting_integration: integration,
             status: 'processing',
             sync_type: 'voucher',
             source_model: 'SalesInvoice',
             source_id: 1,
             processing_started_at: 1.minute.ago,
             response_body: '<VOUCHER></VOUCHER>')
    end

    before do
      request.headers.merge!(auth_headers)
    end

    context 'with valid record' do
      it 'marks record as success' do
        post :ack, params: { id: processing_record.id }

        expect(response).to have_http_status(:ok)
        processing_record.reload
        expect(processing_record.status).to eq('success')
        expect(processing_record.completed_at).to be_present
      end

      it 'includes success message in response' do
        post :ack, params: { id: processing_record.id }

        json = JSON.parse(response.body)
        expect(json['status']).to eq('acknowledged')
        expect(json['sync_record_id']).to eq(processing_record.id)
      end
    end

    context 'when record does not exist' do
      it 'returns 404' do
        post :ack, params: { id: 99999 }
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with invalid authentication' do
      it 'returns 401 unauthorized' do
        request.headers['Authorization'] = 'Bearer invalid_key'
        post :ack, params: { id: processing_record.id }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ─── POST /fail/:id ───────────────────────────────────────────────────────
  describe 'POST #fail' do
    let(:auth_headers) { { 'Authorization' => "Bearer #{api_key}" } }
    let!(:processing_record) do
      create(:accounting_sync_record,
             organization: organization,
             accounting_integration: integration,
             status: 'processing',
             sync_type: 'voucher',
             source_model: 'SalesInvoice',
             source_id: 1,
             processing_started_at: 1.minute.ago,
             attempt_count: 1,
             response_body: '<VOUCHER></VOUCHER>')
    end

    before do
      request.headers.merge!(auth_headers)
    end

    context 'with valid error message' do
      it 'marks record as retrying when under max retries' do
        post :fail, params: {
          id: processing_record.id,
          error_message: 'Connection timeout to Tally'
        }

        expect(response).to have_http_status(:ok)
        processing_record.reload
        expect(processing_record.status).to eq('retrying')
        expect(processing_record.error_message).to eq('Connection timeout to Tally')
      end

      it 'marks record as failed when retries exhausted' do
        processing_record.update!(attempt_count: AccountingSyncRecord::MAX_RETRIES)

        post :fail, params: {
          id: processing_record.id,
          error_message: 'Permanent failure'
        }

        processing_record.reload
        expect(processing_record.status).to eq('failed')
      end
    end

    context 'without error_message parameter' do
      it 'uses default error message' do
        post :fail, params: { id: processing_record.id }

        processing_record.reload
        expect(processing_record.error_message).to be_present
      end
    end

    context 'when record does not exist' do
      it 'returns 404' do
        post :fail, params: { id: 99999, error_message: 'Test error' }
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with invalid authentication' do
      it 'returns 401 unauthorized' do
        request.headers['Authorization'] = 'Bearer invalid_key'
        post :fail, params: { id: processing_record.id, error_message: 'Test' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ─── POST /push_from_tally ────────────────────────────────────────────────
  describe 'POST #push_from_tally' do
    let(:auth_headers) { { 'Authorization' => "Bearer #{api_key}" } }

    before do
      request.headers.merge!(auth_headers)
    end

    it 'returns 501 not implemented' do
      post :push_from_tally, params: {
        entity_type: 'ledger',
        xml_data: '<LEDGER><NAME>Test Ledger</NAME></LEDGER>'
      }

      expect(response).to have_http_status(:not_implemented)
      json = JSON.parse(response.body)
      expect(json['message']).to include('Phase 2.5')
    end
  end
end
