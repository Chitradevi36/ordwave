# frozen_string_literal: true

module Accounting
  module Router
    # Locates the correct active AccountingIntegration for an OMS entity's
    # organisation.
    #
    # Phase 1 contract:
    #   - Returns the single connected/active integration for the org.
    #   - Returns nil (no raise) when no integration exists —
    #     callers must treat nil as "accounting disabled for this org".
    #   - Supports optional provider filtering for future multi-provider support.
    #
    # Usage:
    #   integration = IntegrationResolver.new(invoice).call
    #   integration = IntegrationResolver.new(invoice, provider: "tally").call
    class IntegrationResolver
      # Error raised only when the entity has no determinable organisation,
      # which is a programming mistake, not a user-facing condition.
      class MissingOrganizationError < Accounting::Adapters::Error
        def initialize(entity)
          super("Cannot determine organization for #{entity.class.name}##{entity.try(:id)}")
        end
      end

      # @param entity   [Object]  any OMS ActiveRecord entity
      # @param provider [String, nil]  optional — restrict to this provider slug
      def initialize(entity, provider: nil)
        @entity   = entity
        @provider = provider
      end

      # @return [AccountingIntegration, nil]
      def call
        org = organization_for(@entity)
        raise MissingOrganizationError.new(@entity) if org.nil?

        integration_scope(org).first
      end

      # -----------------------------------------------------------------------
      private
      # -----------------------------------------------------------------------

      # Derive the Organization from the entity via standard associations.
      # All audited OMS models have `belongs_to :organization`.
      def organization_for(entity)
        return entity.organization if entity.respond_to?(:organization) && entity.organization.present?
        return Organization.find_by(id: entity.organization_id) if entity.respond_to?(:organization_id)
        return entity if entity.is_a?(Organization)

        nil
      end

      # Returns an ActiveRecord scope for eligible integrations.
      # Preferred order: connected > active.
      # Restricts to provider if specified.
      def integration_scope(org)
        scope = AccountingIntegration
                  .where(organization: org)
                  .where(status: eligible_statuses)
                  .order(
                    # Prefer connected integrations first, then active (pending connection)
                    Arel.sql(
                      "CASE status WHEN 'connected' THEN 0 WHEN 'active' THEN 1 ELSE 2 END"
                    ),
                    created_at: :desc
                  )

        scope = scope.where(provider: @provider) if @provider.present?
        scope
      end

      # Statuses that allow sync processing.
      # "pending" is intentionally excluded — we require connection confirmation.
      def eligible_statuses
        %w[connected active]
      end
    end
  end
end
