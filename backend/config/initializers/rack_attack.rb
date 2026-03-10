# frozen_string_literal: true

# ── Rack::Attack — rate limiting & brute-force protection ────────────────────
#
# Relies on Rails.cache (configured as Redis in production).
# All limits are per-IP unless otherwise noted.

class Rack::Attack
  # Use Rails cache store (Redis in production, memory in dev/test)
  Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
    url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1")
  )

  # ── Safelists ──────────────────────────────────────────────────────────────
  # Always allow localhost in development
  safelist("allow-localhost") do |req|
    req.ip == "127.0.0.1" || req.ip == "::1"
  end if Rails.env.development?

  # ── Throttle: General API ──────────────────────────────────────────────────
  # 300 requests per 5 minutes per IP for all /api/* routes
  throttle("api/ip", limit: 300, period: 5.minutes) do |req|
    req.ip if req.path.start_with?("/api/")
  end

  # ── Throttle: Login endpoint (per IP) ─────────────────────────────────────
  # 5 attempts per 30 seconds per IP
  throttle("logins/ip", limit: 5, period: 30.seconds) do |req|
    req.ip if req.path == "/api/v1/auth/login" && req.post?
  end

  # ── Throttle: Login endpoint (per email) ──────────────────────────────────
  # 5 attempts per minute per email — prevents credential stuffing
  throttle("logins/email", limit: 5, period: 1.minute) do |req|
    if req.path == "/api/v1/auth/login" && req.post?
      # Parse body (Rack::Attack reads from env, so we use the parsed body)
      body = req.env["rack.input"]&.tap(&:rewind)&.read
      email = begin
        JSON.parse(body.to_s)["email"].to_s.downcase.strip
      rescue StandardError
        nil
      end
      email.presence
    end
  end

  # ── Throttle: Password reset ───────────────────────────────────────────────
  # 5 requests per hour per IP
  throttle("passwords/ip", limit: 5, period: 1.hour) do |req|
    req.ip if req.path.start_with?("/api/v1/passwords/") && req.post?
  end

  # ── Throttle: Signup ───────────────────────────────────────────────────────
  # 20 attempts per hour per IP
  throttle("signup/ip", limit: 20, period: 1.hour) do |req|
    req.ip if req.path.start_with?("/api/v1/signup/") && req.post?
  end

  # ── Throttle: API per authenticated user ──────────────────────────────────
  # 100 requests per minute per user (identified by JWT sub claim)
  throttle("api/user", limit: 100, period: 1.minute) do |req|
    if req.path.start_with?("/api/") && (auth = req.get_header("HTTP_AUTHORIZATION"))
      token = auth.split(" ").last
      begin
        payload = JWT.decode(token, nil, false).first
        payload["sub"]
      rescue
        nil
      end
    end
  end

  # ── Throttle: Sync push per user ──────────────────────────────────────────
  # 10 sync-push requests per minute per user
  throttle("sync/push/user", limit: 10, period: 1.minute) do |req|
    if req.path.start_with?("/api/v1/sync/push") && req.post?
      if (auth = req.get_header("HTTP_AUTHORIZATION"))
        token = auth.split(" ").last
        begin
          payload = JWT.decode(token, nil, false).first
          payload["sub"]
        rescue
          nil
        end
      end
    end
  end

  # ── Throttle: Exports per user ────────────────────────────────────────────
  # 5 export requests per hour per user
  throttle("exports/user", limit: 5, period: 1.hour) do |req|
    if req.path.start_with?("/api/v1/exports") && req.post?
      if (auth = req.get_header("HTTP_AUTHORIZATION"))
        token = auth.split(" ").last
        begin
          payload = JWT.decode(token, nil, false).first
          payload["sub"]
        rescue
          nil
        end
      end
    end
  end

  # ── Blocklist: Repeated forbidden requests ────────────────────────────────
  # Block IPs that hit 403 more than 20 times in 10 minutes
  blocklist("block-suspicious") do |req|
    Rack::Attack::Allow2Ban.filter(req.ip, maxretry: 20, findtime: 10.minutes, bantime: 1.hour) do
      req.env["rack.attack.match_type"] == :throttle
    end
  end

  # ── Response for throttled requests ───────────────────────────────────────
  self.throttled_responder = lambda do |req|
    now        = Time.now
    match_data = req.env["rack.attack.match_data"]
    headers    = {
      "Content-Type"  => "application/json",
      "Retry-After"   => (match_data[:period] - (now.to_i % match_data[:period])).to_s
    }
    [429, headers, [{ errors: ["Too many requests. Please slow down."] }.to_json]]
  end

  # ── Logging ────────────────────────────────────────────────────────────────
  ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |_name, _start, _finish, _req_id, payload|
    req = payload[:request]
    Rails.logger.warn(
      "[Rack::Attack] throttled #{req.env['rack.attack.match_type']} " \
      "ip=#{req.ip} path=#{req.path}"
    )
  end
end
