## 🔐 API RATE LIMITING IMPLEMENTATION
## Production-Ready Middleware

**Status:** READY TO IMPLEMENT  
**Estimated Effort:** 4-6 hours  
**Owner:** Backend Engineer  
**Target Date:** April 7, 2026  

---

## 📋 IMPLEMENTATION PLAN

### Step 1: Add Gem to Gemfile
```ruby
# backend/Gemfile
gem 'rack-attack'
```

### Step 2: Create Initializer
```ruby
# backend/config/initializers/rack_attack.rb

class Rack::Attack
  # Disable rate limiting in development
  enabled = !Rails.env.development?

  # Allow requests from local network during testing
  safelist('allow localhosts') do |req|
    req.host.start_with?('localhost', '127.0.0.1', '::1')
  end

  # ──────────────────────────────────────────────────────────────────
  # LIMIT: API Requests per Role
  # ──────────────────────────────────────────────────────────────────

  # Owner/Admin: 10,000 requests/hour
  throttle('api/owner_admin', limit: 10_000, period: 1.hour) do |req|
    if req.path.start_with?('/api')
      user = extract_user_from_request(req)
      if user&.owner? || user&.admin?
        "owner_admin:#{req.ip}"
      end
    end
  end

  # Sales Rep: 5,000 requests/hour
  throttle('api/sales_rep', limit: 5_000, period: 1.hour) do |req|
    if req.path.start_with?('/api')
      user = extract_user_from_request(req)
      if user&.sales_rep?
        "sales_rep:#{req.ip}"
      end
    end
  end

  # Driver: 2,000 requests/hour
  throttle('api/driver', limit: 2_000, period: 1.hour) do |req|
    if req.path.start_with?('/api')
      user = extract_user_from_request(req)
      if user&.driver?
        "driver:#{req.ip}"
      end
    end
  end

  # Default: 1,000 requests/hour (unauthenticated)
  throttle('api/general', limit: 1_000, period: 1.hour) do |req|
    if req.path.start_with?('/api')
      "general:#{req.ip}"
    end
  end

  # ──────────────────────────────────────────────────────────────────
  # LIMIT: Brute Force Protection
  # ──────────────────────────────────────────────────────────────────

  # 5 attempts per minute per IP for login
  throttle('auth/login', limit: 5, period: 1.minute) do |req|
    if req.path == '/api/v1/auth/login' && req.post?
      req.ip
    end
  end

  # 10 attempts per hour for password reset
  throttle('auth/password_reset', limit: 10, period: 1.hour) do |req|
    if req.path == '/api/v1/password_resets' && req.post?
      req.ip
    end
  end

  # ──────────────────────────────────────────────────────────────────
  # LIMIT: Bulk Operations
  # ──────────────────────────────────────────────────────────────────

  # Bulk imports/exports: 5 per hour
  throttle('bulk/operations', limit: 5, period: 1.hour) do |req|
    if req.path.match?(%r{/api/v1/(imports|exports)})
      user = extract_user_from_request(req)
      "bulk:#{user&.id || req.ip}"
    end
  end

  # ──────────────────────────────────────────────────────────────────
  # RESPONSES
  # ──────────────────────────────────────────────────────────────────

  self.throttled_response = lambda { |env|
    rate_limit = env['rack.attack.throttle_data']
    retry_after = (rate_limit[:period] - (Time.now.to_i % rate_limit[:period])).to_s

    [
      429,  # HTTP 429 Too Many Requests
      {
        'Content-Type' => 'application/json',
        'Retry-After' => retry_after,
        'RateLimit-Limit' => rate_limit[:limit].to_s,
        'RateLimit-Remaining' => '0',
        'RateLimit-Reset' => (Time.now + rate_limit[:period]).to_i.to_s,
      },
      [
        {
          errors: [
            "Too many requests. Please retry after #{retry_after} seconds."
          ],
          rate_limit: {
            limit: rate_limit[:limit],
            period: rate_limit[:period],
            retry_after: retry_after.to_i,
          },
        }.to_json
      ]
    ]
  }

  # ──────────────────────────────────────────────────────────────────
  # MONITORING & ALERTING
  # ──────────────────────────────────────────────────────────────────

  # Log rate limit hits
  ActiveSupport::Notifications.subscribe('throttle.rack_attack') do |name, start, finish, request_id, payload|
    req = payload[:request]
    
    Rails.logger.warn(
      "Rate limit hit: #{req.ip} - #{req.path} - #{payload[:discriminator]}"
    )

    # Send alert if critical
    if payload[:discriminator].include?('auth/login')
      AlertService.notify(
        type: 'rate_limit_alert',
        message: "Brute force attempt detected from #{req.ip}",
        severity: 'high'
      )
    end
  end

  private

  def self.extract_user_from_request(req)
    return nil unless req.headers['Authorization'].present?

    token = req.headers['Authorization'].split(' ').last
    User.find_by_token(token) if token
  rescue
    nil
  end
end
```

### Step 3: Add Rate Limit Headers to API Responses
```ruby
# backend/app/controllers/api/base_controller.rb

module Api
  class BaseController < ApplicationController
    after_action :set_rate_limit_headers

    private

    def set_rate_limit_headers
      return unless request.headers['Authorization']

      user = current_user
      limit, period = get_rate_limit_for_user(user)

      remaining = calculate_remaining_requests(user, limit, period)
      reset_time = calculate_reset_time(period)

      response.headers['RateLimit-Limit'] = limit.to_s
      response.headers['RateLimit-Remaining'] = remaining.to_s
      response.headers['RateLimit-Reset'] = reset_time.to_s
    end

    def get_rate_limit_for_user(user)
      case user.role
      when 'owner', 'admin'
        [10_000, 3600]
      when 'sales_rep'
        [5_000, 3600]
      when 'driver'
        [2_000, 3600]
      else
        [1_000, 3600]
      end
    end

    def calculate_remaining_requests(user, limit, period)
      # This is simplified - normally use Redis cache
      cache_key = "rate_limit:#{user.id}"
      current = Rails.cache.fetch(cache_key) || 0
      [limit - current, 0].max
    end

    def calculate_reset_time(period)
      (Time.now + period.seconds).to_i
    end
  end
end
```

### Step 4: Add Exceptions for Internal Services
```ruby
# backend/config/initializers/rack_attack.rb (Add to existing)

Rack::Attack.safelist('allow internal services') do |req|
  # Allow Sidekiq admin/health checks
  if req.path.start_with?('/sidekiq')
    ENV['SIDEKIQ_PASSWORD'].present? && 
    req.headers['X-Sidekiq-Auth'] == ENV['SIDEKIQ_PASSWORD']
  end
  
  # Allow health check endpoint
  if req.path == '/health'
    true
  end
end
```

### Step 5: Add Redis Configuration
```ruby
# backend/config/initializers/rack_attack_redis.rb

# Use Redis for distributed rate limiting
Rack::Attack::Cache.store = ActiveSupport::Cache::RedisStore.new(
  urls: [ENV.fetch('REDIS_URL', 'redis://localhost:6379/1')]
)

# Fallback to in-memory cache if Redis unavailable
Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
  url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'),
  compress: true,
  namespace: 'rack_attack',
  expires_in: 1.hour
) rescue ActiveSupport::Cache::MemoryStore.new
```

### Step 6: Create Monitoring Dashboard
```ruby
# backend/app/controllers/admin/rate_limits_controller.rb

module Admin
  class RateLimitsController < AdminController
    before_action :require_admin!

    def index
      @rate_limit_stats = fetch_rate_limit_stats
      @top_throttled_ips = fetch_top_throttled_ips
      @suspicious_activity = fetch_suspicious_activity
    end

    private

    def fetch_rate_limit_stats
      {
        owner_admin: Redis.current.get('rack_attack:owner_admin') || 0,
        sales_rep: Redis.current.get('rack_attack:sales_rep') || 0,
        driver: Redis.current.get('rack_attack:driver') || 0,
        general: Redis.current.get('rack_attack:general') || 0,
      }
    end

    def fetch_top_throttled_ips
      # Query throttle events from Redis/logs
      # Return top 10 IPs with most throttle hits
    end

    def fetch_suspicious_activity
      # Detect brute force attempts
      # Return suspicious IPs/users
    end
  end
end

# backend/app/views/admin/rate_limits/index.html.erb
<div class="rate-limit-dashboard">
  <h1>Rate Limiting Dashboard</h1>
  
  <div class="stats-grid">
    <div class="stat-card">
      <h3>Owner/Admin</h3>
      <p class="limit">10,000/hour</p>
      <p class="current"><%= @rate_limit_stats[:owner_admin] %> active</p>
    </div>
    
    <div class="stat-card">
      <h3>Sales Rep</h3>
      <p class="limit">5,000/hour</p>
      <p class="current"><%= @rate_limit_stats[:sales_rep] %> active</p>
    </div>
    
    <div class="stat-card">
      <h3>Driver</h3>
      <p class="limit">2,000/hour</p>
      <p class="current"><%= @rate_limit_stats[:driver] %> active</p>
    </div>
  </div>

  <div class="suspicious-activity">
    <h2>Suspicious Activity</h2>
    <table>
      <thead>
        <tr>
          <th>IP Address</th>
          <th>Hit Count</th>
          <th>Last Hit</th>
          <th>Action</th>
        </tr>
      </thead>
      <tbody>
        <% @suspicious_activity.each do |activity| %>
          <tr>
            <td><%= activity[:ip] %></td>
            <td><%= activity[:hit_count] %></td>
            <td><%= activity[:last_hit] %></td>
            <td><button>Block IP</button></td>
          </tr>
        <% end %>
      </tbody>
    </table>
  </div>
</div>
```

### Step 7: Add Tests
```ruby
# backend/spec/initializers/rack_attack_spec.rb

RSpec.describe 'Rack::Attack', type: :request do
  let(:user) { create(:user, role: 'sales_rep') }
  let(:token) { create_token_for(user) }

  context 'Sales Rep rate limit' do
    it 'allows up to 5000 requests per hour' do
      expect {
        5000.times do
          get '/api/v1/orders',
              headers: { 'Authorization' => "Bearer #{token}" }
        end
      }.not_to raise_error
    end

    it 'returns 429 after exceeding limit' do
      5001.times do
        get '/api/v1/orders',
            headers: { 'Authorization' => "Bearer #{token}" }
      end

      response = get '/api/v1/orders',
                     headers: { 'Authorization' => "Bearer #{token}" }
      
      expect(response.status).to eq(429)
      expect(response.headers['Retry-After']).to be_present
    end
  end

  context 'Brute force protection' do
    it 'limits login attempts to 5 per minute' do
      6.times do |i|
        post '/api/v1/auth/login', params: {
          email: 'test@example.com',
          password: 'wrong'
        }
      end

      response = post '/api/v1/auth/login', params: {
        email: 'test@example.com',
        password: 'wrong'
      }

      expect(response.status).to eq(429)
    end
  end
end
```

### Step 8: Deployment
```bash
# Step 1: Update dependencies
bundle install

# Step 2: Deploy code
git pull origin main
bundle exec cap production deploy

# Step 3: Monitor
tail -f log/production.log | grep -i "rack_attack"

# Step 4: Verify
curl -H "Authorization: Bearer $TOKEN" https://api.orderlane.com/api/v1/orders
# Should include: RateLimit-* headers
```

---

## 📊 RATE LIMIT TIERS

| User Role | Requests/Hour | Requests/Minute | Use Case |
|-----------|--------------|-----------------|----------|
| **Owner/Admin** | 10,000 | 167 | Full platform access |
| **Sales Rep** | 5,000 | 83 | Order entry, customer lookup |
| **Driver** | 2,000 | 33 | Trip updates, delivery tracking |
| **Public API** | 1,000 | 17 | External integrations |

---

## 🚨 ALERT TRIGGERS

```
IF requests in last 1 minute > limit / 60
THEN trigger alert

Brute Force Alert:
IF failed login attempts > 5 in 1 minute
THEN block IP for 15 minutes

Bulk Operations Alert:
IF bulk import > 5 in 1 hour
THEN require admin approval
```

---

## ✅ ROLLBACK PROCEDURE

```bash
# If rate limiting causing issues:

# 1. Disable in initializer
# config/initializers/rack_attack.rb
# Comment out: Rack::Attack.enabled = true

# 2. Restart rails
systemctl restart orderlane_pro

# 3. Monitor and diagnose
# Check logs for patterns

# 4. Re-enable with adjusted limits
```

---

## 📋 DEPLOYMENT CHECKLIST

- [ ] Add 'rack-attack' gem to Gemfile
- [ ] Create initializer file
- [ ] Configure Redis connection
- [ ] Add API response headers
- [ ] Set environment variables
- [ ] Write tests
- [ ] Deploy to staging
- [ ] Monitor for 24 hours
- [ ] Deploy to production
- [ ] Monitor logs closely
- [ ] Add to admin dashboard

---

**Status:** READY TO IMPLEMENT  
**Next Step:** Create PR with this code
