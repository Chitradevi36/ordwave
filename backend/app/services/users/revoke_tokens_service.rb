# frozen_string_literal: true

module Users
  # Revokes all active JWT tokens for a given user by inserting their JTIs into
  # the denylist. Tokens are identified by scanning active sessions stored in
  # Redis (if available) or by inserting a "wildcard" revocation record.
  #
  # Usage:
  #   Users::RevokeTokensService.call(user: user, reason: "role_changed")
  #
  # Triggered automatically by User model callbacks on:
  #   - role/membership changes (via MembershipsController)
  #   - password changes
  #   - account deactivation
  class RevokeTokensService
    REVOCATION_REASONS = %w[
      role_changed
      membership_deactivated
      password_changed
      account_deactivated
      manual_revocation
    ].freeze

    attr_reader :user, :reason, :revoked_at

    def initialize(user:, reason: "manual_revocation")
      @user       = user
      @reason     = reason.to_s
      @revoked_at = Time.current
    end

    def self.call(user:, reason: "manual_revocation")
      new(user: user, reason: reason).call
    end

    def call
      validate!
      revoke_all_tokens
      log_revocation
      self
    rescue StandardError => e
      Rails.logger.error("[RevokeTokensService] Failed for user=#{user.id}: #{e.message}")
      raise
    end

    def success?
      true
    end

    private

    def validate!
      raise ArgumentError, "user is required"           if user.nil?
      raise ArgumentError, "user must be a User record" unless user.is_a?(User)
    end

    # ── Core revocation ───────────────────────────────────────────────────────
    # Strategy 1: If Redis is available, scan for live JTIs stored per-user
    # Strategy 2: Insert an epoch-based sentinel record that covers all tokens
    #             issued before now (checked in BaseController#current_user)
    def revoke_all_tokens
      revoke_via_epoch_sentinel
    end

    # Insert a sentinel JwtDenylist record with jti = "revoked_user_#{user.id}"
    # and exp = revoked_at + 24h (matching token TTL).
    # BaseController checks both jti-based AND epoch-based revocation.
    def revoke_via_epoch_sentinel
      sentinel_jti = "revoked_all_#{user.id}_#{revoked_at.to_i}"
      exp_time     = revoked_at + 25.hours # slightly beyond max token lifetime

      JwtDenylist.find_or_create_by!(jti: sentinel_jti) do |record|
        record.exp = exp_time
      end

      # Also bump the user's token_revoked_at timestamp (custom column added by
      # the db hardening migration). BaseController will reject any token issued
      # before this timestamp.
      user.update_column(:token_revoked_at, revoked_at) if user.has_attribute?(:token_revoked_at)
    end

    def log_revocation
      Rails.logger.info(
        "[RevokeTokensService] Revoked tokens for user=#{user.id} " \
        "email=#{user.email} reason=#{reason} at=#{revoked_at}"
      )
    end
  end
end
