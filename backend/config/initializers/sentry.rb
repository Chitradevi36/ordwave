Sentry.init do |config|
  config.dsn = ENV.fetch("SENTRY_DSN", nil)

  # Only enable if DSN is configured
  config.enabled_environments = %w[production staging]

  # Performance tracing — 10% sample rate in production
  config.traces_sample_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", 0.1).to_f

  # Release tag — set by CI/CD
  config.release = ENV.fetch("HEROKU_SLUG_COMMIT", ENV.fetch("GIT_COMMIT", nil))

  # Filter sensitive parameters
  config.send_default_pii = false

  # Breadcrumb level — info generates a lot; warn is pragmatic
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]

  # Ignore predictable, non-actionable errors
  config.excluded_exceptions += %w[
    ActionController::RoutingError
    ActiveRecord::RecordNotFound
    Pundit::NotAuthorizedError
    JWT::DecodeError
    JWT::ExpiredSignature
  ]

  config.before_send = lambda do |event, _hint|
    # Scrub Authorization headers
    event.request&.headers&.delete("Authorization")
    event.request&.headers&.delete("X-Auth-Token")
    event
  end
end
