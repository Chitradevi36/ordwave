# frozen_string_literal: true

module Api
  module V1
    module Accounting
      class SyncRecordsController < BaseController
        before_action :require_organization!
        before_action :set_record, only: %i[show retry]

        # GET /api/v1/accounting/sync_records
        def index
          scope = policy_scope(AccountingSyncRecord).recent_first
          scope = apply_filters(scope)
          records = paginate(scope)

          render_success(
            records.map { |r| serialize(r) },
            meta: pagination_meta(records).merge(stats: dashboard_stats)
          )
        end

        # GET /api/v1/accounting/sync_records/:id
        def show
          authorize @record
          render_success(serialize(@record, detailed: true))
        end

        # POST /api/v1/accounting/sync_records/:id/retry
        def retry
          authorize @record

          result = ::Accounting::Sync::RetrySyncRecordService.new(@record).call

          case result
          when :enqueued
            render_success({ status: "enqueued", message: "Sync record queued for retry." })
          when :exhausted
            render json: { errors: ["No retry attempts remaining for this record."] },
                   status: :unprocessable_entity
          when :not_eligible
            render json: { errors: ["Record is not in a retryable state (status: #{@record.status})."] },
                   status: :unprocessable_entity
          when :skipped_cooloff
            render json: { errors: ["Cooloff window has not elapsed. Please wait before retrying."] },
                   status: :unprocessable_entity
          else
            render_errors(["Retry failed with unexpected result: #{result}"])
          end
        end

        private

        def set_record
          @record = current_organization
                      .accounting_sync_records
                      .find(params[:id])
        end

        def apply_filters(scope)
          scope = scope.where(status: params[:status])                         if params[:status].present?
          scope = scope.where(priority: params[:priority])                     if params[:priority].present?
          scope = scope.where(entity_type: params[:entity_type])               if params[:entity_type].present?
          scope = scope.where(accounting_integration_id: params[:integration_id]) if params[:integration_id].present?
          scope = scope.where("created_at >= ?", params[:date_from])           if params[:date_from].present?
          if params[:q].present?
            q = "%#{params[:q]}%"
            scope = scope.where(
              "entity_type ILIKE :q OR entity_id::text ILIKE :q OR error_message ILIKE :q",
              q: q
            )
          end
          scope
        end

        def dashboard_stats
          base = current_organization.accounting_sync_records
          {
            pending:       base.where(status: "pending").count,
            processing:    base.where(status: "processing").count,
            success_today: base.where(status: "success")
                               .where("created_at >= ?", Time.current.beginning_of_day)
                               .count,
            failed:        base.where(status: "failed").count,
            last_synced_at: current_organization
                              .accounting_integrations
                              .where.not(last_synced_at: nil)
                              .maximum(:last_synced_at)
          }
        end

        def serialize(record, detailed: false)
          base = {
            id:                    record.id,
            provider:              record.provider,
            entity_type:           record.entity_type,
            entity_id:             record.entity_id,
            entity_version:        record.entity_version,
            event_type:            record.event_type,
            status:                record.status,
            priority:              record.priority,
            attempt_count:         record.attempt_count,
            max_retries:           record.max_retries,
            last_attempted_at:     record.last_attempted_at,
            error_message:         record.error_message,
            accounting_integration: record.accounting_integration && {
              id:       record.accounting_integration.id,
              provider: record.accounting_integration.provider
            },
            created_at:  record.created_at,
            updated_at:  record.updated_at
          }
          if detailed
            base[:payload_json]   = record.payload_json
            base[:response_body]  = record.response_body
          end
          base
        end
      end
    end
  end
end
