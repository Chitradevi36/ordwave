SIDEKIQ_REDIS_CONFIG = {
  url:            ENV.fetch("REDIS_URL", "redis://localhost:6379/0"),
  connect_timeout: 1,
  read_timeout:    3,
  write_timeout:   3,
}.freeze

Sidekiq.configure_server do |config|
  config.redis = SIDEKIQ_REDIS_CONFIG

  # ── Error handler — forwards to Sentry when available ─────────────────────
  config.error_handlers << proc do |ex, ctx_hash|
    if defined?(Sentry)
      Sentry.capture_exception(ex, extra: ctx_hash)
    else
      Rails.logger.error("[Sidekiq] Unhandled error: #{ex.class}: #{ex.message}\n#{ex.backtrace&.first(5)&.join("\n")}")
    end
  end

  # ── Lifecycle hooks for observability ──────────────────────────────────────
  config.on(:startup) do
    Rails.logger.info("[Sidekiq] Worker started — PID #{Process.pid}")
  end

  config.on(:shutdown) do
    Rails.logger.info("[Sidekiq] Worker shutting down — PID #{Process.pid}")
  end
end

Sidekiq.configure_client do |config|
  config.redis = SIDEKIQ_REDIS_CONFIG
end

# ── Default job options ──────────────────────────────────────────────────────
Sidekiq.default_job_options = {
  "retry"   => 5,
  "backtrace" => 10,
}
