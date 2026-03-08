# frozen_string_literal: true

module Accounting
  module Router
    # Derives a stable version token from an OMS entity's current
    # financially-relevant state.
    #
    # The token must:
    #   - change when the entity's exportable content changes
    #   - be deterministic for the same state
    #   - be cheap to compute
    #
    # Strategy (Phase 1):
    #   1. Use lock_version when the model uses optimistic locking.
    #   2. Otherwise use updated_at (millisecond-precision ISO8601).
    #   3. Append status when present (status changes are financially relevant).
    #   4. Fall back to a compact hex digest of id + updated_at string.
    #
    # Do not include user-visible attributes that are not financially relevant
    # (display name, notes, etc.) to avoid spurious version bumps.
    module EntityVersionBuilder
      module_function

      # @param entity [ActiveRecord::Base-like]
      # @return [String] version token
      def call(entity)
        parts = []

        # Optimistic lock version is the most reliable version token when present.
        if entity.respond_to?(:lock_version) && entity.lock_version.present?
          parts << "lv#{entity.lock_version}"
        end

        # updated_at gives sub-second resolution on most PG setups.
        if entity.respond_to?(:updated_at) && entity.updated_at.present?
          parts << entity.updated_at.utc.strftime("%Y%m%dT%H%M%S%6N")
        end

        # Status is financially meaningful — include it so a status change forces
        # a new version even if updated_at wasn't changed (e.g. direct SQL update).
        if entity.respond_to?(:status) && entity.status.present?
          parts << entity.status.to_s
        end

        return digest_fallback(entity) if parts.empty?

        parts.join("_")
      end

      # Digest fallback — used when the entity lacks updated_at / lock_version.
      def digest_fallback(entity)
        raw = "#{entity.class.name}:#{entity.id}"
        Digest::SHA1.hexdigest(raw)[0, 12]
      end
    end
  end
end
