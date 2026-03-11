# frozen_string_literal: true

module Api
  module V1
    module Accounting
      # REST API for OrdWave Tally Agent communication.
      #
      # Endpoints:
      #   POST /api/v1/accounting/agent/register      - Agent registration + API key
      #   POST /api/v1/accounting/agent/heartbeat     - Keepalive (every 30s)
      #   GET  /api/v1/accounting/agent/poll          - Long-polling for pending sync records
      #   POST /api/v1/accounting/agent/ack/:id       - Acknowledge successful sync
      #   POST /api/v1/accounting/agent/fail/:id      - Report failure with error details
      #   POST /api/v1/accounting/agent/push_from_tally - Reverse sync (Tally → OrdWave)
      #
      # Authentication: Agent uses organization-scoped API key in Authorization header
      class AgentController < Api::V1::BaseController
        skip_before_action :authenticate_user!, only: [:register]
        before_action :authenticate_agent!, except: [:register]
        before_action :find_sync_record, only: [:ack, :fail]

        # POST /api/v1/accounting/agent/register
        # Register a new agent and receive API key
        def register
          integration = AccountingIntegration.find_by!(
            id: params[:integration_id],
            organization_id: params[:organization_id]
          )

          # Only allow registration if integration is in realtime_agent mode
          unless integration.sync_mode_realtime_agent?
            return render json: {
              error: "Integration must be in realtime_agent sync mode"
            }, status: :unprocessable_entity
          end

          # Check if agent already exists for this integration
          existing_agent = integration.accounting_agents.first
          if existing_agent
            return render json: {
              error: "Agent already registered for this integration",
              agent_id: existing_agent.agent_id
            }, status: :unprocessable_entity
          end

          agent = AccountingAgent.new(
            organization: integration.organization,
            accounting_integration: integration
          )

          api_key = agent.generate_api_key

          if agent.save
            render json: {
              agent_id: agent.agent_id,
              api_key: api_key,
              message: "Agent registered successfully. Store this API key securely - it will not be shown again."
            }, status: :created
          else
            render json: { errors: agent.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # POST /api/v1/accounting/agent/heartbeat
        # Record agent heartbeat to maintain online status
        def heartbeat
          @current_agent.record_heartbeat!(
            agent_version: params[:agent_version],
            os_info: params[:os_info],
            tally_version: params[:tally_version]
          )

          render json: {
            status: "ok",
            server_time: Time.current.iso8601,
            agent_status: @current_agent.status
          }
        rescue => e
          Rails.logger.error("[AgentController#heartbeat] #{e.class}: #{e.message}")
          render json: { error: "Failed to record heartbeat" }, status: :internal_server_error
        end

        # GET /api/v1/accounting/agent/poll
        # Long-polling endpoint to fetch pending sync records
        # Blocks for up to 30s waiting for new records, returns immediately if records exist
        def poll
          max_records = params[:limit]&.to_i || 10
          max_records = [max_records, 50].min # Cap at 50 records per poll

          integration = @current_agent.accounting_integration

          # Try to get pending records
          records = integration.accounting_sync_records
                              .where(status: %w[pending retrying])
                              .queue_order
                              .limit(max_records)

          # If no records, implement long-polling (simplified version - production would use ActionCable or pub/sub)
          if records.empty?
            sleep_duration = params[:timeout]&.to_i || 30
            sleep_duration = [sleep_duration, 30].min # Cap at 30s

            sleep_duration.times do
              sleep 1
              records = integration.accounting_sync_records
                                  .where(status: %w[pending retrying])
                                  .queue_order
                                  .limit(max_records)
              break if records.any?
            end
          end

          # Mark records as processing
          records.each do |record|
            record.update_columns(
              status: "processing",
              processing_started_at: Time.current
            )
          end

          render json: {
            count: records.size,
            records: records.map { |r| serialize_sync_record(r) }
          }
        rescue => e
          Rails.logger.error("[AgentController#poll] #{e.class}: #{e.message}")
          render json: { error: "Failed to poll sync queue" }, status: :internal_server_error
        end

        # POST /api/v1/accounting/agent/ack/:id
        # Acknowledge successful sync delivery to Tally
        def ack
          ::Accounting::Sync::AgentDeliveryService.new(@sync_record).mark_delivered

          render json: {
            status: "acknowledged",
            sync_record_id: @sync_record.id
          }
        rescue => e
          Rails.logger.error("[AgentController#ack] #{e.class}: #{e.message}")
          render json: { error: "Failed to acknowledge sync" }, status: :internal_server_error
        end

        # POST /api/v1/accounting/agent/fail/:id
        # Report sync failure with error details
        def fail
          error_message = params[:error_message] || "Unknown error"

          ::Accounting::Sync::AgentDeliveryService.new(@sync_record).mark_failed(error_message)

          render json: {
            status: "failed",
            sync_record_id: @sync_record.id,
            will_retry: @sync_record.reload.status_retrying?
          }
        rescue => e
          Rails.logger.error("[AgentController#fail] #{e.class}: #{e.message}")
          render json: { error: "Failed to mark sync as failed" }, status: :internal_server_error
        end

        # POST /api/v1/accounting/agent/push_from_tally
        # Reverse sync: receive a batch of Tally vouchers/balances and reconcile into OrdWave.
        #
        # Expected body:
        #   {
        #     records: [
        #       {
        #         voucher_type: "receipt_voucher",   # receipt_voucher | payment_voucher | closing_balance | ledger_entry
        #         voucher_number: "Rcpt-42",
        #         reference_number: "UTR123456",
        #         party_name: "Sri Murugan Traders",
        #         amount: "15000.00",
        #         date: "20260309",                  # YYYYMMDD (Tally format)
        #         narration: "Payment received"
        #       },
        #       ...
        #     ]
        #   }
        def push_from_tally
          records_params = params.permit(records: [
            :voucher_type, :voucher_number, :reference_number,
            :party_name, :amount, :date, :narration, :closing_balance
          ])[:records] || []

          if records_params.blank?
            return render json: { error: "No records provided" }, status: :unprocessable_entity
          end

          integration = @current_agent.accounting_integration
          results     = ::Accounting::Sync::TallyPushHandlerService.new(integration, records_params).call

          success_count = results.count { |r| r.status == "success" }
          error_count   = results.count { |r| r.status == "error" }

          render json: {
            received: records_params.size,
            success:  success_count,
            skipped:  results.count { |r| r.status == "skipped" },
            errors:   error_count,
            results:  results.map(&:to_h)
          }, status: error_count.zero? ? :ok : :multi_status
        rescue => e
          Rails.logger.error("[AgentController#push_from_tally] #{e.class}: #{e.message}")
          render json: { error: "Failed to process Tally push: #{e.message}" }, status: :internal_server_error
        end

        private

        # Authenticate agent using API key from Authorization header
        def authenticate_agent!
          auth_header = request.headers["Authorization"]

          unless auth_header&.start_with?("Bearer ")
            return render json: { error: "Missing or invalid Authorization header" }, status: :unauthorized
          end

          api_key = auth_header.sub("Bearer ", "")
          agent_id = params[:agent_id]

          agent = AccountingAgent.find_by(agent_id: agent_id)

          unless agent&.verify_api_key(api_key)
            return render json: { error: "Invalid agent credentials" }, status: :unauthorized
          end

          @current_agent = agent
        end

        def find_sync_record
          @sync_record = @current_agent.accounting_integration.accounting_sync_records.find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render json: { error: "Sync record not found" }, status: :not_found
        end

        def serialize_sync_record(record)
          {
            id: record.id,
            entity_type: record.entity_type,
            entity_id: record.entity_id,
            event_type: record.event_type,
            priority: record.priority,
            attempt_count: record.attempt_count,
            xml_payload: record.response_body, # Pre-generated XML from ProcessSyncRecordService
            created_at: record.created_at.iso8601
          }
        end
      end
    end
  end
end
