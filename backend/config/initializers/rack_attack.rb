# frozen_string_literal: true

# ── Rack::Attack — rate limiting & brute-force protection ────────────────────
#
# Two-layer strategy:
#   1. Per-IP global limits  — catch unauthenticated floods / bots
#   2. Per-user (JWT sub)    — granular limits per endpoint group so expensive
#      operations (analytics, compliance, writes) have tighter budgets without
#      penalising lightweight GETs for the same user.
#
# Cache: Redis DB 1 (separate from Sidekiq on DB 0).
# All periods/limits are intentionally conservative and can be tuned via
# ENV overrides — see THROTTLE_* variables below.

class Rack::Attack
  # ── Cache store ────────────────────────────────────────────────────────────
  Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
    url:            ENV.fetch("REDIS_URL", "redis://localhost:6379/1"),
    connect_timeout: 0.5,
    read_timeout:    0.5,
    write_timeout:   0.5,
    error_handler:   ->(method:, returning:, exception:) {
      Rails.logger.error("[Rack::Attack] Redis error on #{method}: #{exception.message}")
    }
  )

  # ── JWT helper ─────────────────────────────────────────────────────────────
  # Extracts the `sub` claim from a Bearer token without verifying the
  # signature (Rack::Attack runs before Rails controllers; we only need the
  # identity for bucketing, not authorization).
  def self.extract_user_id(req)
    auth = req.get_header("HTTP_AUTHORIZATION")
    return nil unless auth&.start_with?("Bearer ")

    token = auth.split(" ", 2).last
    payload = JWT.decode(token, nil, false).first
    payload["sub"].to_s.presence
  rescue StandardError
    nil
  end

  # ── Safelists ──────────────────────────────────────────────────────────────
  safelist("allow-localhost") do |req|
    req.ip == "127.0.0.1" || req.ip == "::1"
  end if Rails.env.development?

  # ─────────────────────────────────────────────────────────────────────────
  # LAYER 1 — Per-IP throttles (unauthenticated safety net)
  # ─────────────────────────────────────────────────────────────────────────

  # General API — 300 req / 5 min per IP
  throttle("api/ip", limit: 300, period: 5.minutes) do |req|
    req.ip if req.path.start_with?("/api/")
  end

  # Login brute-force (per IP) — 5 attempts / 30 sec
  throttle("logins/ip", limit: 5, period: 30.seconds) do |req|
    req.ip if req.path == "/api/v1/auth/login" && req.post?
  end

  # Login credential stuffing (per email) — 5 attempts / 1 min
  throttle("logins/email", limit: 5, period: 1.minute) do |req|
    next unless req.path == "/api/v1/auth/login" && req.post?

    body  = req.env["rack.input"]&.tap(&:rewind)&.read
    email = JSON.parse(body.to_s)["email"].to_s.downcase.strip
    email.presence
  rescue StandardError
    nil
  end

  # Password reset — 5 req / 1 hour per IP
  throttle("passwords/ip", limit: 5, period: 1.hour) do |req|
    req.ip if req.path.start_with?("/api/v1/passwords/") && req.post?
  end

  # Signup — 20 req / 1 hour per IP
  throttle("signup/ip", limit: 20, period: 1.hour) do |req|
    req.ip if req.path.start_with?("/api/v1/signup/") && req.post?
  end

  # ─────────────────────────────────────────────────────────────────────────
  # LAYER 2 — Per-user (JWT sub) throttles
  # ─────────────────────────────────────────────────────────────────────────

  # Global ceiling — 100 req / 1 min catches anything not matched below
  throttle("api/user", limit: 100, period: 1.minute) do |req|
    Rack::Attack.extract_user_id(req) if req.path.start_with?("/api/")
  end

  # ── Write mutations — 30 non-GET req / 1 min ──────────────────────────────
  # Applies to all POST / PATCH / PUT / DELETE on /api/v1/*.
  # Prevents bulk write abuse while leaving read-heavy clients unaffected.
  throttle("api/user/writes", limit: 30, period: 1.minute) do |req|
    next unless req.path.start_with?("/api/v1/") &&
                %w[POST PATCH PUT DELETE].include?(req.request_method)

    Rack::Attack.extract_user_id(req)
  end

  # ── Analytics / Reports / Dashboard — 20 req / 1 min ─────────────────────
  # Paths that trigger expensive aggregation queries.
  ANALYTICS_PATHS = %w[
    /api/v1/analytics
    /api/v1/reports
    /api/v1/dashboard
  ].freeze

  throttle("api/user/analytics", limit: 20, period: 1.minute) do |req|
    next unless ANALYTICS_PATHS.any? { |p| req.path.start_with?(p) }

    Rack::Attack.extract_user_id(req)
  end

  # ── Payments / Financial — 20 req / 1 min ────────────────────────────────
  # Covers payment creation, advances, collection schedules, and credit.
  PAYMENT_PATHS = %w[
    /api/v1/payments
    /api/v1/advance_payments
    /api/v1/collection_schedules
    /api/v1/credit_accounts
    /api/v1/credit_limit_change_requests
  ].freeze

  throttle("api/user/payments", limit: 20, period: 1.minute) do |req|
    next unless PAYMENT_PATHS.any? { |p| req.path.start_with?(p) }

    Rack::Attack.extract_user_id(req)
  end

  # ── Accounting — 10 req / 1 min ───────────────────────────────────────────
  # Sync and export calls to accounting integrations are expensive.
  throttle("api/user/accounting", limit: 10, period: 1.minute) do |req|
    next unless req.path.start_with?("/api/v1/accounting/")

    Rack::Attack.extract_user_id(req)
  end

  # ── Compliance (GST) — 5 req / 1 min ─────────────────────────────────────
  # GST report generation involves large DB scans; very low limit intentional.
  throttle("api/user/compliance", limit: 5, period: 1.minute) do |req|
    next unless req.path.start_with?("/api/v1/compliance/")

    Rack::Attack.extract_user_id(req)
  end

  # ── Sync push — 10 req / 1 min ────────────────────────────────────────────
  throttle("sync/push/user", limit: 10, period: 1.minute) do |req|
    next unless req.path.start_with?("/api/v1/sync/push") && req.post?

    Rack::Attack.extract_user_id(req)
  end

  # ── Exports — 5 req / 1 hour ──────────────────────────────────────────────
  throttle("exports/user", limit: 5, period: 1.hour) do |req|
    next unless req.path.start_with?("/api/v1/exports") && req.post?

    Rack::Attack.extract_user_id(req)
  end

  # ── Token refresh (per IP) — 30 req / 5 min ───────────────────────────────
  # /auth/refresh is called before a valid JWT is available so it can only be
  # keyed by IP. Prevents token-farming / refresh-loop attacks.
  throttle("auth/refresh/ip", limit: 30, period: 5.minutes) do |req|
    req.ip if req.path == "/api/v1/auth/refresh" && req.post?
  end

  # ── Bulk import endpoints — 3 req / 5 min per user ────────────────────────
  # All bulk_import actions trigger file parsing + mass DB inserts.
  # Matches: /api/v1/customers/bulk_import, products/bulk_import, etc.
  throttle("api/user/bulk_import", limit: 3, period: 5.minutes) do |req|
    next unless req.path.end_with?("/bulk_import") &&
                req.path.start_with?("/api/v1/") &&
                req.post?

    Rack::Attack.extract_user_id(req)
  end

  # ── PDF generation — 20 req / 1 min per user ──────────────────────────────
  # Prawn PDF rendering is CPU-bound; one user generating many invoices in a
  # loop can saturate a worker.
  throttle("api/user/pdf", limit: 20, period: 1.minute) do |req|
    next unless req.path.end_with?("/pdf") &&
                req.path.start_with?("/api/v1/") &&
                req.get?

    Rack::Attack.extract_user_id(req)
  end

  # ── e-Invoice / e-Waybill (GST portal calls) — 10 req / 1 min per user ───
  # Each call hits an external GST portal API; runaway calls exhaust third-
  # party quota and incur cost.
  EINVOICE_SUFFIXES = %w[/einvoice /ewaybill /cancel_ewaybill].freeze

  throttle("api/user/einvoice", limit: 10, period: 1.minute) do |req|
    next unless req.path.start_with?("/api/v1/sales_invoices/") &&
                EINVOICE_SUFFIXES.any? { |s| req.path.end_with?(s) } &&
                req.post?

    Rack::Attack.extract_user_id(req)
  end

  # ── Risk profile recompute — 5 req / 1 min per user ───────────────────────
  # Triggers an ML-style scoring pipeline; isolated from the general payments
  # bucket because it's far more expensive and not on a /payments path.
  throttle("api/user/risk_recompute", limit: 5, period: 1.minute) do |req|
    next unless req.path.end_with?("/risk_profile/recompute") &&
                req.path.start_with?("/api/v1/customers/") &&
                req.post?

    Rack::Attack.extract_user_id(req)
  end

  # ── Accounting agent poll/heartbeat — 30 req / 1 min per user ─────────────
  # Agent clients poll on a tight loop; they need a higher limit than the
  # general accounting ceiling (10/min) to avoid false positives.
  AGENT_POLL_PATHS = %w[
    /api/v1/accounting/agent/poll
    /api/v1/accounting/agent/heartbeat
    /api/v1/accounting/agent/register
  ].freeze

  throttle("api/user/accounting/agent", limit: 30, period: 1.minute) do |req|
    next unless AGENT_POLL_PATHS.include?(req.path)

    Rack::Attack.extract_user_id(req)
  end

  # ─────────────────────────────────────────────────────────────────────────
  # BLOCKLIST — Repeated throttle hits → temporary IP ban
  # ─────────────────────────────────────────────────────────────────────────
  blocklist("block-suspicious") do |req|
    Rack::Attack::Allow2Ban.filter(req.ip, maxretry: 20, findtime: 10.minutes, bantime: 1.hour) do
      req.env["rack.attack.match_type"] == :throttle
    end
  end

  # ─────────────────────────────────────────────────────────────────────────
  # 429 RESPONSE — includes throttle name so clients show targeted messages
  # ─────────────────────────────────────────────────────────────────────────
  self.throttled_responder = lambda do |req|
    now        = Time.now.utc
    match_data = req.env["rack.attack.match_data"]
    match_name = req.env["rack.attack.matched"]
    retry_after = (match_data[:period] - (now.to_i % match_data[:period])).to_i

    headers = {
      "Content-Type" => "application/json",
      "Retry-After"  => retry_after.to_s,
      "X-RateLimit-Limit"     => match_data[:limit].to_s,
      "X-RateLimit-Remaining" => "0",
      "X-RateLimit-Reset"     => (now.to_i + retry_after).to_s
    }

    body = {
      errors: ["Too many requests. Please slow down."],
      meta: {
        match:       match_name,
        limit:       match_data[:limit],
        period:      match_data[:period],
        retry_after: retry_after
      }
    }.to_json

    [429, headers, [body]]
  end

  # ─────────────────────────────────────────────────────────────────────────
  # LOGGING — structured warn with match details for observability
  # ─────────────────────────────────────────────────────────────────────────
  ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |_name, _start, _finish, _req_id, payload|
    req        = payload[:request]
    match_data = req.env["rack.attack.match_data"] || {}
    Rails.logger.warn(
      "[Rack::Attack] throttled" \
      " match=#{req.env['rack.attack.matched']}" \
      " ip=#{req.ip}" \
      " path=#{req.path}" \
      " method=#{req.request_method}" \
      " count=#{match_data[:count]}" \
      " limit=#{match_data[:limit]}" \
      " period=#{match_data[:period]}"
    )
  end

  ActiveSupport::Notifications.subscribe("blocklist.rack_attack") do |_name, _start, _finish, _req_id, payload|
    req = payload[:request]
    Rails.logger.warn(
      "[Rack::Attack] blocked" \
      " match=#{req.env['rack.attack.matched']}" \
      " ip=#{req.ip}" \
      " path=#{req.path}"
    )
  end
end
