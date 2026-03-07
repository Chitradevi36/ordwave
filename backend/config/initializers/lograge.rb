Rails.application.configure do
  config.lograge.enabled = true

  # Use JSON so log aggregators (Datadog, CloudWatch, etc.) can parse structured logs
  config.lograge.formatter = Lograge::Formatters::Json.new

  config.lograge.ignore_actions = [
    "Api::V1::HealthController#show"
  ]

  # Add custom fields to every request log line
  config.lograge.custom_options = lambda do |event|
    {
      request_id:      event.payload[:request_id],
      user_id:         event.payload[:user_id],
      organization_id: event.payload[:organization_id],
      params:          event.payload[:params]
                         &.except("controller", "action", "format")
                         &.to_s
                         &.truncate(500),
      exception:       event.payload[:exception]&.first,
      exception_object: event.payload[:exception_object]&.message&.truncate(200),
    }.compact
  end
end
