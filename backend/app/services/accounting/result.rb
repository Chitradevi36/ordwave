# frozen_string_literal: true

module Accounting
  # Lightweight immutable result objects shared by the router and sync services.
  # These replace boolean returns with readable structured outcomes.
  module Result
    # -------------------------------------------------------------------------
    # DispatchResult — returned by Router::DispatchService
    # -------------------------------------------------------------------------
    DispatchResult = Struct.new(:status, :sync_record, :message, keyword_init: true) do
      # status values: :enqueued, :skipped, :no_integration, :duplicate, :error

      def enqueued?  = status == :enqueued
      def skipped?   = status == :skipped
      def duplicate? = status == :duplicate
      def no_integration? = status == :no_integration
      def error?     = status == :error
      def ok?        = enqueued? || duplicate? || skipped?

      def to_s
        "#<DispatchResult status=#{status} #{message}>"
      end
    end

    # -------------------------------------------------------------------------
    # CreateSyncResult — returned by Sync::CreateSyncRecordService
    # -------------------------------------------------------------------------
    CreateSyncResult = Struct.new(:status, :sync_record, :message, keyword_init: true) do
      # status values: :created, :duplicate, :error

      def created?   = status == :created
      def duplicate? = status == :duplicate
      def error?     = status == :error
    end
  end
end
