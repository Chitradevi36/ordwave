# frozen_string_literal: true

module Accounting
  module Sync
    # Creates an AccountingSyncRecord for one OMS entity + event combination and
    # enqueues a ProcessSyncRecordJob.
    #
    # Idempotency guarantee:
    #   If a sync record with the same idempotency_key already exists AND is in
    #   a completed or pending/processing state, a new record is not created.
    #   Only if the existing record is in a final-failed state (no retries left)
    #   will a fresh record be created for a re-drive.
    #
    # The service does NOT touch the source entity — it only reads it.
    class CreateSyncRecordService
      # @param entity      [Object]               OMS ActiveRecord entity
      # @param integration [AccountingIntegration]
      # @param event_type  [String]               e.g. "invoice_issued"
      # @param provider    [String, nil]
      def initialize(entity:, integration:, event_type:, provider: nil)
        @entity      = entity
        @integration = integration
        @event_type  = event_type.to_s
        @provider    = (provider || integration.provider).to_s
      end

      # @return [Accounting::Result::CreateSyncResult]
      def call
        # 1. Build version and idempotency key.
        version         = Router::EntityVersionBuilder.call(@entity)
        idempotency_key = Router::IdempotencyKeyBuilder.call(
          provider:       @provider,
          entity:         @entity,
          event_type:     @event_type,
          entity_version: version
        )

        # 2. Duplicate check.
        existing = find_existing(idempotency_key)
        if existing && !should_recreate?(existing)
          return Accounting::Result::CreateSyncResult.new(
            status:      :duplicate,
            sync_record: existing,
            message:     "sync record #{existing.id} already exists with status=#{existing.status}"
          )
        end

        # 3. Build canonical object from source entity.
        canonical = map_to_canonical(@entity)

        # 4. Build payload snapshot.
        payload = build_payload_snapshot(canonical, version)

        # 5. Determine priority.
        priority = Router::PriorityResolver.call(entity: @entity, event_type: @event_type)

        # 6. Persist sync record.
        sync_record = persist_sync_record(
          idempotency_key: idempotency_key,
          entity_version:  version,
          priority:        priority,
          payload:         payload,
          canonical:       canonical
        )

        # 7. Enqueue processing job.
        Accounting::ProcessSyncRecordJob.perform_later(sync_record.id)

        Accounting::Result::CreateSyncResult.new(
          status:      :created,
          sync_record: sync_record,
          message:     "Created sync record #{sync_record.id}"
        )
      rescue ActiveRecord::RecordNotUnique
        # DB unique constraint race — reload and return duplicate.
        existing = AccountingSyncRecord.find_by(idempotency_key: idempotency_key)
        Accounting::Result::CreateSyncResult.new(
          status:      :duplicate,
          sync_record: existing,
          message:     "Race condition: duplicate sync record for idempotency_key"
        )
      rescue => e
        Rails.logger.error("[CreateSyncRecordService] #{e.class}: #{e.message}")
        Accounting::Result::CreateSyncResult.new(status: :error, message: e.message)
      end

      # -----------------------------------------------------------------------
      private
      # -----------------------------------------------------------------------

      def find_existing(idempotency_key)
        AccountingSyncRecord.find_by(idempotency_key: idempotency_key)
      end

      # We recreate a record only if the existing one is permanently failed with
      # no retries remaining — it can't progress on its own anymore.
      def should_recreate?(record)
        record.failed? && record.attempts >= record.max_attempts
      end

      def map_to_canonical(entity)
        mapper_klass = Router::MapperResolver.call(entity)
        mapper_klass.call(entity)
      end

      def build_payload_snapshot(canonical, entity_version)
        {
          canonical_type: canonical.class.name,
          canonical_data: canonical.to_h,
          metadata:       {
            source_type:     @entity.class.name,
            source_id:       @entity.id,
            organization_id: organization_id,
            branch_id:       @entity.try(:branch_id),
            event_type:      @event_type,
            entity_version:  entity_version,
            generated_at:    Time.current.iso8601,
            provider:        @provider
          }
        }
      end

      def persist_sync_record(idempotency_key:, entity_version:, priority:, payload:, canonical:)
        AccountingSyncRecord.create!(
          organization:           organization,
          accounting_integration: @integration,
          entity_type:            @entity.class.name,
          entity_id:              @entity.id,
          entity_version:         entity_version,
          event_type:             @event_type,
          provider:               @provider,
          direction:              "outbound",
          status:                 "pending",
          priority:               priority,
          idempotency_key:        idempotency_key,
          payload_json:           payload
        )
      end

      def organization
        @organization ||= resolve_organization
      end

      def organization_id
        organization&.id
      end

      def resolve_organization
        return @entity.organization if @entity.respond_to?(:organization) && !@entity.organization.nil?
        return Organization.find_by(id: @entity.organization_id) if @entity.respond_to?(:organization_id)

        nil
      end
    end
  end
end
