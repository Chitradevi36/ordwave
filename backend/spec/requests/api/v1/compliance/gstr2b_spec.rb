# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Compliance::Gstr2b', type: :request do
  include AuthHelper   # provides auth_headers(user, org)

  let(:org)      { create(:organization, gst_number: '27AAPFU0939F1ZV') }
  let(:manager)  { create(:user) }
  let(:headers)  { auth_headers(manager, org) }

  # Minimal valid GSTR-2B JSON structure
  let(:valid_payload) do
    {
      data: {
        docdata: {
          b2b: [
            {
              ctin:  '29AALCA0943A1ZM',
              trdnm: 'Test Supplier',
              inv: [
                {
                  inum: 'INV-TEST-001',
                  dt:   '15-09-2025',
                  val:  118_000.0,
                  Rev: 'N',
                  pos: '27',
                  itms: [
                    {
                      itm_det: {
                        txval: 100_000.0,
                        iamt:  18_000.0,
                        camt:  0.0,
                        samt:  0.0,
                        csamt: 0.0
                      }
                    }
                  ]
                }
              ]
            }
          ]
        }
      }
    }
  end

  describe 'GET /api/v1/compliance/gstr2b/imports' do
    before do
      create_list(:gst2b_import, 3, organization: org, month: 9, year: 2025)
    end

    it 'returns imports for the organization' do
      get '/api/v1/compliance/gstr2b/imports', headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(3)
    end

    it 'filters by month and year' do
      create(:gst2b_import, organization: org, month: 10, year: 2025)
      get '/api/v1/compliance/gstr2b/imports', params: { month: 9, year: 2025 }, headers: headers
      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(3)
    end

    it 'requires authentication' do
      get '/api/v1/compliance/gstr2b/imports'
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/compliance/gstr2b/import' do
    let(:valid_params) do
      {
        gstin:        '27AAPFU0939F1ZV',
        month:        9,
        year:         2025,
        json_payload: valid_payload
      }
    end

    context 'with valid parameters' do
      it 'creates a new import record' do
        expect {
          post '/api/v1/compliance/gstr2b/import', params: valid_params, headers: headers
        }.to change(Gst2bImport, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['data']['import_status']).to eq('completed')
        expect(json['data']['gstin']).to eq('27AAPFU0939F1ZV')
      end
    end

    context 'with an invalid GSTIN' do
      it 'returns unprocessable_entity' do
        post '/api/v1/compliance/gstr2b/import',
             params: valid_params.merge(gstin: 'INVALID'), headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to include('GSTIN is invalid or missing')
      end
    end

    context 'with missing required params' do
      it 'returns unprocessable_entity when gstin is missing' do
        post '/api/v1/compliance/gstr2b/import',
             params: valid_params.except(:gstin), headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with invalid JSON payload' do
      it 'returns a parse error' do
        post '/api/v1/compliance/gstr2b/import',
             params: valid_params.merge(json_payload: 'not-valid-json{{{'),
             headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'GET /api/v1/compliance/gstr2b/imports/:id' do
    let!(:import) { create(:gst2b_import, organization: org) }

    it 'returns the import detail' do
      get "/api/v1/compliance/gstr2b/imports/#{import.id}", headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['id']).to eq(import.id)
    end

    it 'returns 404 for unknown import' do
      get '/api/v1/compliance/gstr2b/imports/99999', headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it 'does not expose imports from other organizations' do
      other_import = create(:gst2b_import, organization: create(:organization))
      get "/api/v1/compliance/gstr2b/imports/#{other_import.id}", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /api/v1/compliance/gstr2b/imports/:id/lines' do
    let!(:import) { create(:gst2b_import, organization: org) }

    before do
      create_list(:gst2b_import_line, 5, gst2b_import: import, organization: org)
    end

    it 'returns paginated lines' do
      get "/api/v1/compliance/gstr2b/imports/#{import.id}/lines", headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['lines'].length).to eq(5)
      expect(json['data']['total']).to eq(5)
    end

    it 'filters by match_status' do
      create(:gst2b_import_line, :matched, gst2b_import: import, organization: org)
      get "/api/v1/compliance/gstr2b/imports/#{import.id}/lines",
          params: { match_status: 'matched' }, headers: headers
      json = JSON.parse(response.body)
      expect(json['data']['lines'].length).to eq(1)
    end
  end
end
