# frozen_string_literal: true

module Api
  module V1
    # Handles retailer risk profile reads and on-demand recomputation.
    #
    #   GET  /api/v1/customers/:customer_id/risk_profile
    #   POST /api/v1/customers/:customer_id/risk_profile/recompute
    #   GET  /api/v1/credit/risk/riskiest
    class RetailerRiskController < BaseController
      before_action :require_organization!
      before_action :load_customer, except: :riskiest

      # GET /api/v1/customers/:customer_id/risk_profile
      def show
        snapshot = RetailerRiskSnapshot
          .where(customer: @customer, organization: current_organization)
          .order(computed_at: :desc)
          .first

        # Auto-compute if never computed or stale (>6 hours)
        if snapshot.nil? || snapshot.stale?
          snapshot = Credit::RetailerRiskEngine.compute_and_save!(@customer)
        end

        authorize snapshot, :show?
        render_success serialize_snapshot(snapshot)
      end

      # POST /api/v1/customers/:customer_id/risk_profile/recompute
      def recompute
        dummy = RetailerRiskSnapshot.new(organization: current_organization, customer: @customer)
        authorize dummy, :create?

        snapshot = Credit::RetailerRiskEngine.compute_and_save!(@customer)
        render_success serialize_snapshot(snapshot)
      end

      # GET /api/v1/credit/risk/riskiest?limit=10
      def riskiest
        authorize RetailerRiskSnapshot.new(organization: current_organization), :index?

        limit = [[params[:limit].to_i, 1].max, 50].min
        limit = 10 if limit == 0

        # Fetch the most recent snapshot per customer for this org,
        # ordered by risk_score desc
        snapshots = RetailerRiskSnapshot
          .where(organization: current_organization)
          .where("computed_at > ?", 48.hours.ago)
          .order(risk_score: :desc)
          .limit(limit)
          .includes(:customer)

        render_success snapshots.map { |s|
          serialize_snapshot(s).merge(
            customer_name: s.customer.name,
            customer_code: s.customer.code,
            customer_id:   s.customer_id,
          )
        }
      end

      private

      def load_customer
        @customer = Customer.not_deleted
                            .where(organization: current_organization)
                            .find(params[:customer_id])
      end

      def serialize_snapshot(snapshot)
        {
          id:             snapshot.id,
          customer_id:    snapshot.customer_id,
          risk_score:     snapshot.risk_score,
          risk_tier:      snapshot.risk_tier,
          recommendation: snapshot.recommendation,
          factors:        snapshot.factor_list,
          score_version:  snapshot.score_version,
          computed_at:    snapshot.computed_at&.iso8601,
          stale:          snapshot.stale?,
        }
      end
    end
  end
end
