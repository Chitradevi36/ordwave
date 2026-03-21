# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Webhooks::TwilioController', type: :request do
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization: organization, phone: '+91-9876543210') }
  let(:order) { create(:sales_order, organization: organization, customer: customer) }
  let(:trip) { create(:delivery_trip, organization: organization) }
  let(:stop) { create(:trip_stop, delivery_trip: trip, sales_order: order) }
  let(:reschedule) do
    create(:reschedule_delivery,
           organization: organization,
           trip_stop: stop,
           sales_order: order,
           customer: customer,
           status: 'pending',
           next_retry_date: Date.current + 3.days)
  end

  let(:base_params) do
    {
      From: customer.phone,
      Body: 'DECLINE',
      MessageSid: 'SM1234567890',
      AccountSid: ENV.fetch('TWILIO_ACCOUNT_SID', 'test'),
      MessageCount: '1'
    }
  end

  describe 'POST /api/v1/webhooks/twilio/sms_reply' do
    context 'with valid Twilio signature' do
      let(:signature) do
        url = "http://www.example.com/api/v1/webhooks/twilio/sms_reply"
        body_string = base_params.to_query
        auth_token = ENV.fetch('TWILIO_AUTH_TOKEN', 'test')
        data = url + body_string
        OpenSSL::HMAC.digest(
          OpenSSL::Digest.new('sha1'),
          auth_token,
          data
        ).encode('base64').strip
      end

      before do
        # Note: In real tests, we'd need to mock the signature validation
        # Here we're testing the happy path assuming signature validation passes
        allow_any_instance_of(Api::V1::Webhooks::TwilioController)
          .to receive(:validate_twilio_request)
          .and_return(true)
      end

      it 'accepts DECLINE response' do
        reschedule # Create reschedule record
        
        post '/api/v1/webhooks/twilio/sms_reply', params: base_params
        
        expect(response).to have_http_status(:ok)
        
        # Verify notification_data was updated
        reschedule.reload
        expect(reschedule.notification_data['customer_reply']).to be_present
        expect(reschedule.notification_data['customer_declined_reschedule']).to be_present
      end

      it 'accepts RESCHEDULE response' do
        reschedule # Create reschedule record
        
        post '/api/v1/webhooks/twilio/sms_reply', params: base_params.merge(Body: 'RESCHEDULE')
        
        expect(response).to have_http_status(:ok)
        
        reschedule.reload
        expect(reschedule.notification_data['customer_wants_reschedule']).to be_present
      end

      it 'handles unknown responses' do
        reschedule # Create reschedule record
        allow(TwilioClient).to receive(:enabled?).and_return(true)
        
        expect(TwilioClient).to receive(:send_sms).with(
          phone_number: customer.phone,
          message: include('Reply with')
        )
        
        post '/api/v1/webhooks/twilio/sms_reply', params: base_params.merge(Body: 'MAYBE LATER')
        
        expect(response).to have_http_status(:ok)
      end

      it 'creates ops notification on customer decline' do
        manager_user = create(:user, organization: organization)
        manager_role = create(:role, organization: organization, name: 'manager')
        create(:membership, user: manager_user, organization: organization, role: manager_role)
        
        reschedule # Create reschedule record
        
        expect {
          post '/api/v1/webhooks/twilio/sms_reply', params: base_params.merge(Body: 'DECLINE')
        }.to change { Notification.where(notification_type: 'delivery_declined').count }.by(1)
        
        notification = Notification.where(notification_type: 'delivery_declined').last
        expect(notification.user).to eq(manager_user)
        expect(notification.severity).to eq('high')
      end
    end

    context 'with invalid Twilio signature' do
      before do
        allow_any_instance_of(Api::V1::Webhooks::TwilioController)
          .to receive(:validate_twilio_request)
          .and_return(false)
      end

      it 'rejects request' do
        post '/api/v1/webhooks/twilio/sms_reply', params: base_params
        
        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['error']).to include('Invalid request signature')
      end
    end

    context 'with missing customer' do
      before do
        allow_any_instance_of(Api::V1::Webhooks::TwilioController)
          .to receive(:validate_twilio_request)
          .and_return(true)
      end

      it 'handles gracefully' do
        post '/api/v1/webhooks/twilio/sms_reply', params: base_params.merge(From: '+91-1111111111')
        
        expect(response).to have_http_status(:ok)  # Still 200 to prevent Twilio retries
      end
    end

    context 'with no active reschedule' do
      before do
        allow_any_instance_of(Api::V1::Webhooks::TwilioController)
          .to receive(:validate_twilio_request)
          .and_return(true)
      end

      it 'handles gracefully' do
        # Create customer but no reschedule
        post '/api/v1/webhooks/twilio/sms_reply', params: base_params
        
        expect(response).to have_http_status(:ok)  # Still 200 to prevent Twilio retries
      end
    end

    context 'with multiple reschedules' do
      before do
        allow_any_instance_of(Api::V1::Webhooks::TwilioController)
          .to receive(:validate_twilio_request)
          .and_return(true)
      end

      it 'processes the most recent one' do
        # Create two reschedules
        old_reschedule = create(:reschedule_delivery,
                                organization: organization,
                                customer: customer,
                                sales_order: order,
                                status: 'pending',
                                created_at: 2.days.ago)
        new_reschedule = create(:reschedule_delivery,
                                organization: organization,
                                customer: customer,
                                sales_order: create(:sales_order, organization: organization, customer: customer),
                                status: 'pending',
                                created_at: 1.hour.ago)
        
        post '/api/v1/webhooks/twilio/sms_reply', params: base_params.merge(Body: 'DECLINE')
        
        expect(response).to have_http_status(:ok)
        
        # New reschedule should have decline data, not the old one
        expect(new_reschedule.reload.notification_data['customer_declined_reschedule']).to be_present
        expect(old_reschedule.reload.notification_data['customer_declined_reschedule']).to be_nil
      end
    end
  end
end
