module Api
  module V1
    class StockTransfersController < BaseController
      before_action :require_organization!
      before_action :set_transfer, only: %i[show update dispatch_transfer receive cancel]

      TRANSFER_INCLUDES = [
        { lines: [:product] },
        :source_branch,
        :destination_branch,
        :created_by,
        :dispatched_by,
        :received_by,
        { stock_movements: [:product] },
        :audit_logs
      ].freeze

      # GET /api/v1/stock_transfers
      def index
        scope = policy_scope(StockTransfer)
        scope = scope.for_branch(params[:branch_id])          if params[:branch_id].present?
        scope = scope.for_source(params[:source_branch_id])   if params[:source_branch_id].present?
        scope = scope.for_destination(params[:destination_branch_id]) if params[:destination_branch_id].present?
        scope = scope.by_status(params[:status])              if params[:status].present?
        scope = scope.in_date_range(params[:date_from], params[:date_to])
        scope = scope.search_q(params[:q])                    if params[:q].present?

        transfers = paginate(scope.includes(TRANSFER_INCLUDES).recent)

        render_success(
          transfers.map { |t| serialize_transfer(t) },
          meta: pagination_meta(transfers)
        )
      end

      # GET /api/v1/stock_transfers/:id
      def show
        authorize @transfer
        render_success(serialize_transfer(@transfer, detailed: true))
      end

      # POST /api/v1/stock_transfers
      def create
        authorize StockTransfer.new(organization: current_organization)

        result = Transfers::CreateDraftTransfer.new(
          params:       transfer_params,
          organization: current_organization,
          actor:        current_user
        ).call

        if result.success?
          render_created(serialize_transfer(result.transfer, detailed: true))
        else
          render_errors(result.errors)
        end
      end

      # PATCH /api/v1/stock_transfers/:id
      def update
        authorize @transfer

        result = Transfers::UpdateDraftTransfer.new(
          transfer: @transfer,
          params:   transfer_params,
          actor:    current_user
        ).call

        if result.success?
          render_success(serialize_transfer(result.transfer.reload, detailed: true))
        else
          render_errors(result.errors)
        end
      end

      # POST /api/v1/stock_transfers/:id/dispatch
      def dispatch_transfer
        authorize @transfer, :dispatch?

        result = Transfers::DispatchTransfer.new(
          transfer:         @transfer,
          actor:            current_user,
          dispatched_lines: params[:lines] || []
        ).call

        if result.success?
          render_success(serialize_transfer(result.transfer, detailed: true))
        else
          render_errors(result.errors)
        end
      end

      # POST /api/v1/stock_transfers/:id/receive
      def receive
        authorize @transfer, :receive?

        result = Transfers::ReceiveTransfer.new(
          transfer:       @transfer,
          actor:          current_user,
          received_lines: params[:lines] || []
        ).call

        if result.success?
          render_success(serialize_transfer(result.transfer, detailed: true))
        else
          render_errors(result.errors)
        end
      end

      # POST /api/v1/stock_transfers/:id/cancel
      def cancel
        authorize @transfer, :cancel?

        result = Transfers::CancelTransfer.new(
          transfer: @transfer,
          actor:    current_user,
          reason:   params[:reason]
        ).call

        if result.success?
          render_success(serialize_transfer(result.transfer, detailed: true))
        else
          render_errors(result.errors)
        end
      end

      private

      def set_transfer
        @transfer = StockTransfer
          .for_org(current_organization)
          .includes(TRANSFER_INCLUDES)
          .find(params[:id])
      end

      def transfer_params
        params.require(:stock_transfer).permit(
          :source_branch_id, :destination_branch_id,
          :transfer_date, :notes,
          lines: %i[product_id qty_requested]
        )
      end

      def serialize_transfer(transfer, detailed: false)
        data = {
          id:              transfer.id,
          transfer_number: transfer.transfer_number,
          transfer_date:   transfer.transfer_date,
          status:          transfer.status,
          notes:           transfer.notes,
          dispatched_at:   transfer.dispatched_at,
          received_at:     transfer.received_at,
          cancellation_reason: transfer.cancellation_reason,
          created_at:      transfer.created_at,
          updated_at:      transfer.updated_at,
          lines_count:     transfer.lines.size,
          total_qty_dispatched: transfer.lines.sum(&:qty_dispatched),
          total_qty_received:   transfer.lines.sum(&:qty_received),
          source_branch: transfer.source_branch ? {
            id:   transfer.source_branch.id,
            name: transfer.source_branch.name
          } : nil,
          destination_branch: transfer.destination_branch ? {
            id:   transfer.destination_branch.id,
            name: transfer.destination_branch.name
          } : nil,
          created_by: transfer.created_by ? {
            id:   transfer.created_by.id,
            name: transfer.created_by.full_name
          } : nil,
          dispatched_by: transfer.dispatched_by ? {
            id:   transfer.dispatched_by.id,
            name: transfer.dispatched_by.full_name
          } : nil,
          received_by: transfer.received_by ? {
            id:   transfer.received_by.id,
            name: transfer.received_by.full_name
          } : nil
        }

        if detailed
          data[:lines] = transfer.lines.map do |line|
            {
              id:            line.id,
              product_id:    line.product_id,
              product_name:  line.product&.name,
              product_sku:   line.product&.sku,
              qty_requested: line.qty_requested,
              qty_dispatched:line.qty_dispatched,
              qty_received:  line.qty_received,
              qty_damaged:   line.qty_damaged,
              qty_in_transit:line.qty_in_transit,
              reason_code:   line.reason_code,
              fully_accounted: line.fully_accounted?
            }
          end

          data[:stock_movements] = transfer.stock_movements
                                     .order(created_at: :asc)
                                     .map do |sm|
            {
              id:            sm.id,
              movement_type: sm.movement_type,
              direction:     sm.direction,
              product_id:    sm.product_id,
              product_name:  sm.product&.name,
              qty:           sm.qty,
              branch_id:     sm.branch_id,
              occurred_at:   sm.occurred_at,
              created_at:    sm.created_at
            }
          end

          data[:timeline] = transfer.audit_logs
                              .order(created_at: :asc)
                              .map do |log|
            {
              id:         log.id,
              action:     log.action,
              changes:    log.changes_data,
              actor_name: log.actor&.full_name,
              created_at: log.created_at
            }
          end
        end

        data
      end
    end
  end
end
