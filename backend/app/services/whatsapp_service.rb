require 'json'
require 'net/http'
require 'uri'

class WhatsappService
  class ConfigError < StandardError; end
  class WhatsAppSendError < StandardError; end

  DEFAULT_ENDPOINT = 'https://api.msg91.com/api/v5/whatsapp/whatsapp-outbound-message/bulk/'.freeze
  DEFAULT_LANGUAGE = 'en'.freeze

  def initialize
    validate_config!
    @auth_key = ENV.fetch('MSG91_AUTH_KEY')
    @integrated_number = ENV.fetch('MSG91_WHATSAPP_INTEGRATED_NUMBER')
    @endpoint = ENV.fetch('MSG91_WHATSAPP_ENDPOINT', DEFAULT_ENDPOINT)
  end

  def send_login_otp(phone_number, otp_code)
    send_otp_template(phone_number, otp_code, message_type: 'login_otp')
  end

  def send_registration_otp(phone_number, otp_code)
    send_otp_template(phone_number, otp_code, message_type: 'registration_otp')
  end

  private

  def send_otp_template(phone_number, otp_code, metadata = {})
    recipient = normalise_phone_number(phone_number)
    request_body = build_otp_payload(recipient, otp_code)
    response_body = post_json(request_body)
    request_id = extract_request_id(response_body)

    Rails.logger.info(
      "MSG91 WhatsApp OTP sent to #{recipient} request_id=#{request_id} type=#{metadata[:message_type]}"
    )

    request_id
  rescue ConfigError
    raise
  rescue StandardError => e
    error_msg = "Failed to send WhatsApp OTP: #{e.message}"
    Rails.logger.error(error_msg)
    raise WhatsAppSendError, error_msg
  end

  def build_otp_payload(recipient, otp_code)
    template = {
      name: ENV.fetch('MSG91_WHATSAPP_OTP_TEMPLATE_NAME'),
      language: {
        code: ENV.fetch('MSG91_WHATSAPP_OTP_TEMPLATE_LANGUAGE', DEFAULT_LANGUAGE),
        policy: 'deterministic'
      },
      to_and_components: [
        {
          to: [recipient],
          components: otp_components(otp_code)
        }
      ]
    }

    namespace = ENV.fetch('MSG91_WHATSAPP_OTP_TEMPLATE_NAMESPACE', nil)
    template[:namespace] = namespace if namespace.present?

    {
      integrated_number: @integrated_number,
      content_type: 'template',
      payload: {
        messaging_product: 'whatsapp',
        type: 'template',
        template: template
      }
    }
  end

  def otp_components(otp_code)
    components = {
      body_1: {
        type: 'text',
        value: otp_code.to_s
      }
    }

    if ENV.fetch('MSG91_WHATSAPP_OTP_BUTTON_ENABLED', 'true') == 'true'
      components[:button_1] = {
        subtype: 'url',
        type: 'text',
        value: otp_code.to_s
      }
    end

    components
  end

  def post_json(request_body)
    uri = URI.parse(@endpoint)
    request = Net::HTTP::Post.new(uri)
    request['accept'] = 'application/json'
    request['authkey'] = @auth_key
    request['content-type'] = 'application/json'
    request.body = JSON.generate(request_body)

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
      http.request(request)
    end

    unless response.is_a?(Net::HTTPSuccess)
      raise WhatsAppSendError, "MSG91 WhatsApp HTTP error: #{response.code} #{response.message} #{response.body}"
    end

    Rails.logger.info(parse_response(response.body))    
    parse_response(response.body)
  end

  def parse_response(body)
    JSON.parse(body.to_s)
  rescue JSON::ParserError
    { 'message' => body.to_s.strip }
  end

  def extract_request_id(response_body)
    response_body['request_id'] ||
      response_body['message_uuid'] ||
      response_body['message'] ||
      response_body['data'] ||
      response_body.to_s
  end

  def validate_config!
    required_keys = %w[
      MSG91_AUTH_KEY
      MSG91_WHATSAPP_INTEGRATED_NUMBER
      MSG91_WHATSAPP_OTP_TEMPLATE_NAME
    ]
    missing_keys = required_keys.reject { |key| ENV[key].present? }

    return if missing_keys.empty?

    raise ConfigError,
          "Missing WhatsApp configuration: #{missing_keys.join(', ')}\n" \
          "Add to .env: #{missing_keys.map { |key| "#{key}=..." }.join(', ')}"
  end

  def normalise_phone_number(phone_number)
    digits = phone_number.to_s.gsub(/[^0-9]/, '')
    digits = digits.sub(/^0+/, '')

    return digits if digits.length > 10

    "91#{digits.slice(-10, 10)}"
  end
end
