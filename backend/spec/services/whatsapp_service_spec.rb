require 'rails_helper'

RSpec.describe WhatsappService do
  let(:endpoint) { 'https://api.msg91.com/api/v5/whatsapp/whatsapp-outbound-message/bulk/' }

  around do |example|
    original_env = ENV.to_h

    ENV['MSG91_AUTH_KEY'] = 'test-auth-key'
    ENV['MSG91_WHATSAPP_INTEGRATED_NUMBER'] = '919092599389'
    ENV['MSG91_WHATSAPP_OTP_TEMPLATE_NAME'] = 'login_otp'
    ENV['MSG91_WHATSAPP_OTP_TEMPLATE_LANGUAGE'] = 'en'
    ENV['MSG91_WHATSAPP_OTP_TEMPLATE_NAMESPACE'] = nil
    ENV['MSG91_WHATSAPP_OTP_BUTTON_ENABLED'] = 'true'
    ENV['MSG91_WHATSAPP_ENDPOINT'] = endpoint

    example.run
  ensure
    ENV.replace(original_env)
  end

  describe '#send_login_otp' do
    it 'sends a MSG91 WhatsApp OTP template request' do
      request = stub_request(:post, endpoint)
        .with(
          headers: {
            'accept' => 'application/json',
            'authkey' => 'test-auth-key',
            'content-type' => 'application/json'
          }
        )
        .to_return(
          status: 200,
          body: { request_id: 'msg91-request-123' }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      result = described_class.new.send_login_otp('9876543210', '123456')

      expect(result).to eq('msg91-request-123')
      expect(request).to have_been_requested

      body = JSON.parse(WebMock::RequestRegistry.instance.requested_signatures.hash.keys.first.body)
      template = body.fetch('payload').fetch('template')
      components = template.fetch('to_and_components').first.fetch('components')

      expect(body.fetch('integrated_number')).to eq('919999999999')
      expect(template.fetch('name')).to eq('ordwave_login_otp')
      expect(template.fetch('to_and_components').first.fetch('to')).to eq(['919876543210'])
      expect(components.fetch('body_1')).to eq({ 'type' => 'text', 'value' => '123456' })
      expect(components.fetch('button_1')).to eq({ 'subtype' => 'url', 'type' => 'text', 'value' => '123456' })
    end
  end

  describe '#send_registration_otp' do
    it 'can send without the optional WhatsApp button component' do
      ENV['MSG91_WHATSAPP_OTP_BUTTON_ENABLED'] = 'false'

      stub_request(:post, endpoint).to_return(
        status: 200,
        body: { request_id: 'msg91-request-456' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

      result = described_class.new.send_registration_otp('+91 98765 43210', '654321')
      body = JSON.parse(WebMock::RequestRegistry.instance.requested_signatures.hash.keys.last.body)
      components = body.fetch('payload').fetch('template').fetch('to_and_components').first.fetch('components')

      expect(result).to eq('msg91-request-456')
      expect(components).to include('body_1')
      expect(components).not_to include('button_1')
    end
  end
end
