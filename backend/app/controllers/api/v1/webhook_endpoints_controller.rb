module Api
  module V1
    class WebhookEndpointsController < BaseController
      before_action :require_organization!
      before_action :set_endpoint, only: %i[show update destroy]

      # GET /api/v1/webhook_endpoints
      def index
        endpoints = policy_scope(
          WebhookEndpoint.where(organization: current_organization).order(created_at: :desc)
        )
        authorize WebhookEndpoint
        render_success(endpoints.map { |ep| serialize(ep) })
      end

      # GET /api/v1/webhook_endpoints/:id
      def show
        authorize @endpoint
        render_success(serialize(@endpoint, include_secret: true))
      end

      # POST /api/v1/webhook_endpoints
      def create
        authorize WebhookEndpoint
        endpoint = WebhookEndpoint.new(endpoint_params.merge(organization: current_organization))
        if endpoint.save
          render_created(serialize(endpoint, include_secret: true))
        else
          render_errors(endpoint.errors.full_messages)
        end
      end

      # PATCH /api/v1/webhook_endpoints/:id
      def update
        authorize @endpoint
        if @endpoint.update(endpoint_params)
          render_success(serialize(@endpoint))
        else
          render_errors(@endpoint.errors.full_messages)
        end
      end

      # DELETE /api/v1/webhook_endpoints/:id
      def destroy
        authorize @endpoint
        @endpoint.destroy!
        head :no_content
      end

      # POST /api/v1/webhook_endpoints/:id/test
      def test
        set_endpoint
        authorize @endpoint, :update?

        DeliverWebhookJob.perform_later(
          WebhookDelivery.create!(
            webhook_endpoint: @endpoint,
            organization:     current_organization,
            event:            "test.ping",
            payload:          { test: true, timestamp: Time.current.iso8601 }
          ).id
        )

        render_success({ message: "Test delivery enqueued" })
      end

      private

      def set_endpoint
        @endpoint = WebhookEndpoint.find_by!(
          id:           params[:id],
          organization: current_organization
        )
      end

      def endpoint_params
        params.require(:webhook_endpoint).permit(:url, :description, :active, events: [])
      end

      def serialize(ep, include_secret: false)
        {
          id:                 ep.id,
          url:                ep.url,
          description:        ep.description,
          events:             ep.events,
          active:             ep.active,
          failure_count:      ep.failure_count,
          last_success_at:    ep.last_success_at,
          last_failure_at:    ep.last_failure_at,
          last_failure_reason: ep.last_failure_reason,
          created_at:         ep.created_at,
        }.tap do |h|
          h[:secret] = ep.secret if include_secret
        end
      end
    end
  end
end
