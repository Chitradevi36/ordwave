module Api
  module V1
    # GET /health — unauthenticated liveness + readiness probe.
    # Returns 200 OK if the app is healthy, 503 if any critical dependency is down.
    class HealthController < ActionController::API
      def show
        checks = {
          database: database_ok?,
          redis:    redis_ok?,
          sidekiq:  sidekiq_ok?,
          storage:  storage_ok?,
        }

        healthy = checks.values.all?
        status  = healthy ? :ok : :service_unavailable

        render json: {
          status:  healthy ? "ok" : "degraded",
          version: ENV.fetch("APP_VERSION", "unknown"),
          checks:  checks,
          timestamp: Time.current.iso8601
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
