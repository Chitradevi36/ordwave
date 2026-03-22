# frozen_string_literal: true

module Api
  module V1
    class InvoiceQuarantinesController < BaseController
      before_action :set_quarantine, only: %i[show reprocess mark_resolved]

      # GET /api/v1/invoice_quarantines
      # Lists quarantined failed invoice generations with filtering
      def index
        quarantines = policy_scope(InvoiceGenerationQuarantine)
                        .for_org(Current.organization)
                        .includes(:trip_stop, :sales_order, :branch, :resolved_by)
                        .order(created_at: :desc)

        # Filter by status
        quarantines = quarantines.by_status(params[:status]) if params[:status].present?

        # Filter by urgency
        if params[:urgent].present?
          quarantine_ids = quarantines.map { |q| q.quarantine_urgent? ? q.id : nil }.compact
          quarantines = quarantines.where(id: quarantine_ids)
        end

        # Filter by date range
        if params[:days_old].present?
          quarantines = quarantines.by_days_old(params[:days_old].to_i)
        end

        quarantines = quarantines.page(params[:page]).per(params[:per_page] || 25)

        render json: quarantines.map { |q| InvoiceQuarantineSerializer.new(q).serialize },
               meta: pagination_meta(quarantines)
      end

      # GET /api/v1/invoice_quarantines/stats
      # Returns dashboard stats about quarantine queue
      def stats
        org = Current.organization
        quarantines = org.invoice_generation_quarantines.unresolved

        render json: {
          data: {
            total_quarantined: quarantines.count,
            urgent_count: quarantines.map { |q| q.quarantine_urgent? ? 1 : 0 }.sum,
            oldest_days: quarantines.oldest_first.first&.days_in_quarantine || 0,
            by_status: quarantines.group(:status).count,
            total_lost_amount: calculate_total_lost_amount(quarantines)
          }
        }
      end

      # GET /api/v1/invoice_quarantines/:id
      def show
        authorize @quarantine
        render json: InvoiceQuarantineSerializer.new(@quarantine).serialize
      end

      # POST /api/v1/invoice_quarantines/:id/reprocess
      # Retries the invoice generation from quarantine
      def reprocess
        authorize @quarantine, :reprocess?

        result = Invoicing::ReprocessQuarantineService.call(
          quarantine: @quarantine,
          user: Current.user
        )

        if result.success?
          render json: {
            data: InvoiceQuarantineSerializer.new(@quarantine.reload).serialize,
            message: result.message,
            invoice: result.invoice
          }
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/invoice_quarantines/:id/mark_resolved
      # Manually mark a quarantine as resolved (e.g., manual invoice created)
      def mark_resolved
        authorize @quarantine, :mark_resolved?

        @quarantine.update!(
          status: 'resolved',
          resolved_at: Time.current,
          resolved_by: Current.user
        )

        render json: InvoiceQuarantineSerializer.new(@quarantine).serialize
      end

      private

      def set_quarantine
        @quarantine = policy_scope(InvoiceGenerationQuarantine)
                        .for_org(Current.organization)
                        .find(params[:id])
      end

      def calculate_total_lost_amount(quarantines)
        # Sum up the would-be invoice amounts for urgency indicator
        quarantines.sum do |q|
          q.sales_order.total_amount rescue 0
        end
      end
    end
  end
end
