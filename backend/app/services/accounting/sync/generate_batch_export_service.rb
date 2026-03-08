# frozen_string_literal: true

module Accounting
  module Sync
    # Generates a Tally XML batch export file from an AccountingExportFile record.
    #
    # The service:
    #   1. Collects OMS records within the export's date/org scope.
    #   2. Maps them to canonical POROs via existing mappers.
    #   3. Delegates XML assembly to Accounting::Adapters::Tally::BatchExportBuilder.
    #   4. Writes master XML and/or voucher XML to disk.
    #   5. Updates AccountingExportFile to ready or failed.
    #
    # Output files are written under tmp/exports/<organization_id>/ by default.
    # This path is straightforward to swap for ActiveStorage in a future phase.
    class GenerateBatchExportService
      EXPORT_TYPES = %w[all invoices payments credit_notes purchase_invoices masters].freeze

      EXPORT_DIR = Rails.root.join("tmp", "exports").freeze

      # @param accounting_export_file [AccountingExportFile]
      def initialize(accounting_export_file)
        @export_file = accounting_export_file
        @integration = accounting_export_file.accounting_integration
        @org         = accounting_export_file.organization
      end

      def call
        validate!

        entities       = entities_for_export
        batch_xml      = build_batch_xml(entities)
        paths          = write_files!(batch_xml)

        @export_file.update!(
          status:    "ready",
          file_path: paths.values.compact.join(",")
        )

        Rails.logger.info(
          "[GenerateBatchExportService] export_file##{@export_file.id} ready. " \
          "Files: #{paths.inspect}"
        )

        paths
      rescue => e
        Rails.logger.error("[GenerateBatchExportService] #{e.class}: #{e.message}")
        @export_file.update_columns(
          status:        "failed",
          error_message: "#{e.class}: #{e.message}"
        )
        raise
      end

      # -----------------------------------------------------------------------
      private
      # -----------------------------------------------------------------------

      def validate!
        raise ArgumentError, "Export file has no integration" unless @integration.present?
        raise ArgumentError, "Export file has no organization" unless @org.present?

        et = @export_file.export_type.to_s
        unless EXPORT_TYPES.include?(et)
          raise ArgumentError, "Unsupported export_type '#{et}'. Must be one of: #{EXPORT_TYPES.join(', ')}"
        end
      end

      # -----------------------------------------------------------------------
      # Source record scoping
      # -----------------------------------------------------------------------

      def entities_for_export
        case @export_file.export_type.to_s
        when "all"
          source_records_for("invoices") +
            source_records_for("payments") +
            source_records_for("credit_notes") +
            source_records_for("purchase_invoices") +
            source_records_for("masters")
        else
          source_records_for(@export_file.export_type)
        end
      end

      # Returns an Array of canonical POROs for the given type slice.
      def source_records_for(type)
        orm_records = source_scope_for_export_type(type)
        orm_records.map do |record|
          begin
            mapper_klass = Router::MapperResolver.call(record)
            mapper_klass.call(record)
          rescue Router::MapperResolver::NoMapperFoundError => e
            Rails.logger.warn("[GenerateBatchExportService] Skipping #{record.class.name}##{record.id}: #{e.message}")
            nil
          end
        end.compact
      end

      # Returns an ActiveRecord relation for a single export type.
      def source_scope_for_export_type(type)
        date_from = @export_file.date_from
        date_to   = @export_file.date_to
        branch_id = @export_file.branch_id

        case type
        when "invoices"
          scope = SalesInvoice.where(organization: @org)
                              .where(status: %w[issued partially_paid])
          scope = scope.where(branch_id: branch_id) if branch_id.present?
          scope = filter_by_date(scope, :invoice_date, date_from, date_to)
          scope.order(:invoice_date)

        when "payments"
          scope = Payment.where(organization: @org)
          scope = scope.where(branch_id: branch_id) if branch_id.present?
          scope = filter_by_date(scope, :received_date, date_from, date_to)
          scope.order(:received_date)

        when "credit_notes"
          scope = CreditNote.where(organization: @org)
                            .where(status: %w[issued])
          scope = scope.where(branch_id: branch_id) if branch_id.present?
          scope = filter_by_date(scope, :created_at, date_from, date_to)
          scope.order(:created_at)

        when "purchase_invoices"
          scope = PurchaseInvoice.where(organization: @org)
          scope = scope.where(branch_id: branch_id) if branch_id.present?
          scope = filter_by_date(scope, :invoice_date, date_from, date_to)
          scope.order(:invoice_date)

        when "masters"
          # Combine customers, suppliers, products — return a plain Array.
          customers  = Customer.where(organization: @org, status: "active").to_a
          suppliers  = Supplier.where(organization: @org, status: "active").to_a
          products   = Product.where(organization: @org, status: "active").to_a
          customers + suppliers + products

        else
          []
        end
      end

      def filter_by_date(scope, date_column, date_from, date_to)
        scope = scope.where("#{date_column} >= ?", date_from) if date_from.present?
        scope = scope.where("#{date_column} <= ?", date_to)   if date_to.present?
        scope
      end

      # -----------------------------------------------------------------------
      # XML Generation
      # -----------------------------------------------------------------------

      def build_batch_xml(entities)
        adapter      = Accounting::Adapters::Factory.build(@integration)
        company_name = adapter.respond_to?(:config) ? adapter.config.company_name : nil

        Accounting::Adapters::Tally::BatchExportBuilder.call(
          entities:     entities,
          company_name: company_name
        )
      end

      # -----------------------------------------------------------------------
      # File output
      # -----------------------------------------------------------------------

      # Writes masters XML and/or vouchers XML to disk.
      # Returns a hash of { masters: path, vouchers: path } (nil if not present).
      def write_files!(batch_xml)
        dir = EXPORT_DIR.join(@org.id.to_s)
        FileUtils.mkdir_p(dir)

        paths = {}

        if batch_xml[:masters].present?
          path          = dir.join("#{file_name("masters")}.xml")
          File.write(path, batch_xml[:masters])
          paths[:masters] = path.to_s
        end

        if batch_xml[:vouchers].present?
          path           = dir.join("#{file_name("vouchers")}.xml")
          File.write(path, batch_xml[:vouchers])
          paths[:vouchers] = path.to_s
        end

        paths
      end

      def file_name(kind)
        ts = Time.current.strftime("%Y%m%d_%H%M%S")
        "tally_#{kind}_export_#{@export_file.id}_#{ts}"
      end
    end
  end
end
