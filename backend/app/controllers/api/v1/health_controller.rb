module Api
  module V1
    # GET /health — unauthenticated liveness + readiness probe.
    # Returns 200 OK if the app is healthy, 503 if any critical dependency is down.
    class HealthController < ActionController::API
      # Current minimum mobile version required to use the app.
      # Bump this to force-update older builds.
      MIN_MOBILE_VERSION = ENV.fetch("MIN_MOBILE_VERSION", "1.0.0")

      def show
        db_ok      = database_ok?
        redis_ok   = redis_ok?
        sidekiq_ok = sidekiq_ok?

        services = {
          database: db_ok      ? "connected"                  : "error",
          redis:    redis_ok   ? "connected"                  : "error",
          sidekiq:  sidekiq_ok ? sidekiq_status               : "not running",
        }

        healthy = db_ok && redis_ok
        status  = healthy ? :ok : :service_unavailable

        render json: {
          status:              healthy ? "healthy" : "degraded",
          version:             ENV.fetch("APP_VERSION", "1.0.0"),
          min_mobile_version:  MIN_MOBILE_VERSION,
          maintenance_mode:    ENV.fetch("MAINTENANCE_MODE", "false") == "true",
          timestamp:           Time.current.iso8601,
          services:            services,
        }, status: status
      end

      private

      def database_ok?
        ActiveRecord::Base.connection.execute("SELECT 1")
        true
      rescue => e
        Rails.logger.error("[Health] DB check failed: #{e.message}")
        false
      end

      def redis_ok?
        Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0")).ping == "PONG"
      rescue => e
        Rails.logger.error("[Health] Redis check failed: #{e.message}")
        false
      end

      def sidekiq_ok?
        Sidekiq::Stats.new.queues.any? { true }
        true
      rescue => e
        Rails.logger.error("[Health] Sidekiq check failed: #{e.message}")
        false
      end

      def sidekiq_status
        stats = Sidekiq::Stats.new
        workers = Sidekiq::Workers.new.count
        "running (#{workers} worker#{workers == 1 ? '' : 's'}, #{stats.enqueued} enqueued)"
      rescue
        "running"
      end

      def storage_ok?
        # Only verify Active Storage is configured; actual file operations tested separately
        ActiveStorage::Blob.service.present?
        true
      rescue => e
        Rails.logger.error("[Health] Storage check failed: #{e.message}")
        false
      end
    end
  end
end
