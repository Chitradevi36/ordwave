require 'json'
require 'net/http'
require 'uri'

class WhatsappService
  class ConfigError < StandardError; end
  class WhatsAppSendError < StandardError; end

  DEFAULT_ENDPOINT = 'https://api.msg91.com/api/v5/whatsapp/whatsapp-outbound-message/bulk/'.freeze
  DEFAULT_LANGUAGE = 'en'.freeze
  TEMPLATE_CONFIG_PATH = Rails.root.join('config', 'whatsapp_templates.json').freeze

  def initialize
    validate_config!
    @auth_key = ENV.fetch('MSG91_AUTH_KEY')
    @integrated_number = ENV.fetch('MSG91_WHATSAPP_INTEGRATED_NUMBER')
    @endpoint = ENV.fetch('MSG91_WHATSAPP_ENDPOINT', DEFAULT_ENDPOINT)
  end

  def send_template(template_key, phone_number:, **vars)
    definition = template_definitions.fetch(template_key.to_s)

    send_template_message(
      phone_number: phone_number,
      template_name: resolved_template_name(definition),
      components: resolve_components(definition.fetch('components'), vars),
      config_prefix: definition['config_prefix'],
      language_code: definition['language_code'],
      success_log_template: definition.fetch('success_log'),
      failure_label: definition.fetch('failure_label')
    )
  rescue KeyError => e
    raise ConfigError, "Unknown WhatsApp template #{template_key}: #{e.message}"
  end

  private

  def send_template_message(phone_number:, template_name:, components:, config_prefix: nil, language_code: nil, success_log_template:, failure_label:)
    recipient = normalise_phone_number(phone_number)
    request_body = build_template_payload(
      recipient: recipient,
      template_name: template_name,
      components: components,
      config_prefix: config_prefix,
      language_code: language_code
    )
    response_body = post_json(request_body)
    request_id = extract_request_id(response_body)

    Rails.logger.info(
      interpolate_placeholders(
        success_log_template,
        recipient: recipient,
        request_id: request_id,
        response_body: response_body.inspect
      )
    )

    response_body.is_a?(Hash) ? request_id : response_body
  rescue ConfigError
    raise
  rescue StandardError => e
    error_msg = "Failed to send #{failure_label}: #{e.message}"
    Rails.logger.error(error_msg)
    raise WhatsAppSendError, error_msg
  end

  def build_template_payload(recipient:, template_name:, components:, config_prefix: nil, language_code: nil)
    template = {
      name: template_name,
      language: {
        code: template_language(config_prefix, language_code),
        policy: 'deterministic'
      },
      to_and_components: [
        {
          to: [recipient],
          components: components
        }
      ]
    }

    namespace = template_namespace(config_prefix)
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

  def resolved_template_name(definition)
    return definition['template_name'] if definition['template_name'].present?

    ENV.fetch(definition.fetch('template_name_env'))
  end

  def template_language(config_prefix, explicit_language_code)
    return explicit_language_code if explicit_language_code.present?
    return DEFAULT_LANGUAGE if config_prefix.blank?

    ENV.fetch("#{config_prefix}_LANGUAGE", DEFAULT_LANGUAGE)
  end

  def template_namespace(config_prefix)
    return nil if config_prefix.blank?

    ENV.fetch("#{config_prefix}_NAMESPACE", nil)
  end

  def template_definitions
    @template_definitions ||= JSON.parse(File.read(TEMPLATE_CONFIG_PATH))
  rescue Errno::ENOENT => e
    raise ConfigError, "Missing WhatsApp template config file: #{e.message}"
  rescue JSON::ParserError => e
    raise ConfigError, "Invalid WhatsApp template config JSON: #{e.message}"
  end

  def resolve_components(component_definition, vars)
    component_definition.each_with_object({}) do |(component_key, component_config), resolved|
      next unless component_enabled?(component_config)

      resolved[component_key.to_sym] = resolve_component_config(component_config, vars)
    end
  end

  def component_enabled?(component_config)
    env_key = component_config['enabled_env']
    return true if env_key.blank?

    ENV.fetch(env_key, nil).to_s == component_config.fetch('enabled_when', 'true')
  end

  def resolve_component_config(component_config, vars)
    component_config.each_with_object({}) do |(key, value), resolved|
      next if %w[enabled_env enabled_when].include?(key)

      resolved[key.to_sym] = value.is_a?(String) ? interpolate_placeholders(value, vars) : value
    end
  end

  def interpolate_placeholders(template, vars)
    template.gsub(/\{\{([^}]+)\}\}/) do
      key = Regexp.last_match(1).strip
      vars.fetch(key.to_sym).to_s
    end
  rescue KeyError => e
    raise ConfigError, "Missing WhatsApp template variable #{e.message} for '#{template}'"
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
      MSG91_WHATSAPP_INVITATION_TEMPLATE_NAME
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
