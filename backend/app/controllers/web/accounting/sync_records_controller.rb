# frozen_string_literal: true

module Web
  module Accounting
    # Sync dashboard — operational visibility into outbound accounting syncs.
    #
    # Screens:
    #   GET  /web/accounting/sync_records           — index (dashboard + table)
    #   GET  /web/accounting/sync_records/:id       — show  (detail + JSON blobs)
    #   POST /web/accounting/sync_records/:id/retry — retry failed record
    class SyncRecordsController < Web::BaseController
      helper Web::AccountingHelper

      before_action :set_sync_record, only: %i[show retry]

      PER_PAGE = 25

      # GET /web/accounting/sync_records
      def index
        authorize AccountingSyncRecord
        base   = policy_scope(AccountingSyncRecord).includes(:accounting_integration)
        base   = apply_filters(base)
        @stats = build_stats(policy_scope(AccountingSyncRecord))
        @sync_records = base.order(created_at: :desc)
                            .page(params[:page]).per(PER_PAGE)
        @integrations = AccountingIntegration.where(organization: current_organization)
                                             .order(:provider)
      end

      # GET /web/accounting/sync_records/:id
      def show
        authorize @sync_record
      end

      # POST /web/accounting/sync_records/:id/retry
      def retry
        authorize @sync_record

        unless @sync_record.retryable?
          return redirect_to web_accounting_sync_record_path(@sync_record),
                             alert: "This record cannot be retried (status: #{@sync_record.status}, " \
                                    "attempts: #{@sync_record.attempt_count}/#{@sync_record.max_retries_for_priority})."
        end

        result = ::Accounting::Sync::RetrySyncRecordService.new(@sync_record).call

        case result
        when :enqueued
          redirect_to web_accounting_sync_record_path(@sync_record),
                      notice: "Sync record queued for retry."
        when :exhausted
          redirect_to web_accounting_sync_record_path(@sync_record),
                      alert: "Maximum retry attempts reached — cannot retry further."
        when :skipped_cooloff
          redirect_to web_accounting_sync_record_path(@sync_record),
                      warning: "Retry skipped — cooloff period has not elapsed yet."
        else
          # Fallback: enqueue directly
          ::Accounting::ProcessSyncRecordJob.perform_later(@sync_record.id)
          @sync_record.mark_retrying!(message: "Manual retry triggered via admin UI")
          redirect_to web_accounting_sync_record_path(@sync_record),
                      notice: "Retry job enqueued."
        end
      rescue StandardError => e
        Rails.logger.error("[SyncRecordsController#retry] #{e.class}: #{e.message}")
        redirect_to web_accounting_sync_record_path(@sync_record),
                    alert: "Could not retry: #{e.message}"
      end

      private

      def set_sync_record
        @sync_record = policy_scope(AccountingSyncRecord)
                         .includes(:accounting_integration)
                         .find(params[:id])
      end

      # ── Filtering ─────────────────────────────────────────────────────────

      def apply_filters(scope)
        scope = scope.where(status: params[:status])            if params[:status].present?
        scope = scope.where(priority: params[:priority])        if params[:priority].present?
        scope = scope.where(provider: params[:provider])        if params[:provider].present?
        scope = scope.where(entity_type: params[:entity_type])  if params[:entity_type].present?
        scope = scope.where(event_type: params[:event_type])    if params[:event_type].present?
        scope = scope.where(accounting_integration_id: params[:integration_id]) if params[:integration_id].present?

        if params[:date_from].present?
          begin
            scope = scope.where("created_at >= ?", Date.parse(params[:date_from]).beginning_of_day)
          rescue ArgumentError
            # ignore malformed date
          end
        end

        if params[:date_to].present?
          begin
            scope = scope.where("created_at <= ?", Date.parse(params[:date_to]).end_of_day)
          rescue ArgumentError
            # ignore malformed date
          end
        end

        if params[:q].present?
          q = "%#{params[:q].strip}%"
          scope = scope.where(
            "entity_id::text ILIKE :q OR idempotency_key ILIKE :q OR external_reference ILIKE :q",
            q: q
          )
        end

        scope
      end

      # ── Dashboard stats ────────────────────────────────────────────────────

      def build_stats(scoped)
        today_start = Time.current.beginning_of_day
        {
          pending:       scoped.where(status: "pending").count,
          processing:    scoped.where(status: "processing").count,
          success_today: scoped.where(status: "success").where("succeeded_at >= ?", today_start).count,
          failed:        scoped.where(status: "failed").count,
          last_sync_at:  scoped.where(status: "success").maximum(:succeeded_at)
        }
      end
    end
  end
end
