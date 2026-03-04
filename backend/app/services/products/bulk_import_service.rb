require 'csv'

module Products
  # Imports Product records from an uploaded CSV file for the given organisation.
  #
  # Expected CSV columns (case-insensitive headers):
  #   sku*          – unique within org (uppercase letters, numbers, hyphens, underscores)
  #   name*         – product display name
  #   category_name – matched to existing ProductCategory; created if missing
  #   uom_symbol    – matched to existing UnitsOfMeasure symbol (e.g. KG, PCS)
  #   hsn_code*     – matched against HsnSacCode.code master; gst_rate auto-filled
  #   min_order_qty – positive integer (default: 1)
  #   purchase_price – decimal ≥ 0 (optional)
  #   barcode        – optional string
  #   weight_kg      – decimal > 0 (optional)
  #   description    – optional text
  #   image_url      – optional URL
  #   status         – active | discontinued (default: active)
  #
  # Behaviour:
  #   - Each row runs in its own transaction; failures do not roll back others.
  #   - Rows whose SKU already exists in the org are skipped.
  #   - hsn_code is looked up in the master table; row fails if not found.
  #   - gst_rate is auto-filled by the model callback from the resolved HsnSacCode.
  #
  # Usage:
  #   result = Products::BulkImportService.new(file: params[:file], organization: org).call
  #   result.success_count   # Integer
  #   result.skipped_rows    # [{ row: 3, sku: 'PROD-001', reason: '...' }]
  #   result.failed_rows     # [{ row: 4, sku: 'PROD-002', errors: ['...'] }]
  #
  class BulkImportService
    Result = Struct.new(:success_count, :skipped_rows, :failed_rows, keyword_init: true)

    MAX_ROWS = 2_000

    SAMPLE_HEADERS = %w[
      sku name category_name uom_symbol hsn_code
      min_order_qty purchase_price barcode weight_kg
      description image_url status
    ].freeze

    def initialize(file:, organization:)
      @file         = file
      @organization = organization
    end

    def call
      success_count = 0
      skipped_rows  = []
      failed_rows   = []
      row_number    = 1

      csv_data = read_csv
      if csv_data[:error]
        return Result.new(success_count: 0, skipped_rows: [],
                          failed_rows: [{ row: 0, errors: [csv_data[:error]] }])
      end

      rows = csv_data[:rows]
      if rows.size > MAX_ROWS
        return Result.new(
          success_count: 0, skipped_rows: [],
          failed_rows: [{ row: 0, errors: ["File has #{rows.size} rows; maximum allowed is #{MAX_ROWS}"] }]
        )
      end

      # Pre-cache lookups to avoid N+1 queries
      category_cache = @organization.product_categories
                                    .where(deleted_at: nil)
                                    .index_by { |c| c.name.downcase.strip }
      uom_cache      = UnitsOfMeasure.where(active: true)
                                    .index_by { |u| u.symbol.downcase.strip }
      hsn_cache      = HsnSacCode.where(active: true)
                                 .index_by { |h| h.code.strip }

      rows.each do |row|
        row_number += 1
        sku = row['sku'].to_s.strip.upcase

        if @organization.products.not_deleted.exists?(sku: sku)
          skipped_rows << { row: row_number, sku: sku, reason: 'SKU already exists in this organisation' }
          next
        end

        attrs, error = build_attrs(row, sku, category_cache, uom_cache, hsn_cache)
        if error
          failed_rows << { row: row_number, sku: sku, errors: [error] }
          next
        end

        ActiveRecord::Base.transaction do
          # Resolve/create category inside the transaction so it rolls back
          # atomically if the product save fails — no orphaned categories.
          if attrs[:_category_name]
            cat_name = attrs.delete(:_category_name)
            category = category_cache[cat_name.downcase]
            unless category
              category = @organization.product_categories.create!(name: cat_name)
              category_cache[cat_name.downcase] = category
            end
            attrs[:product_category_id] = category.id
          end

          product = Product.new(attrs.merge(organization: @organization))
          if product.save
            success_count += 1
          else
            failed_rows << { row: row_number, sku: sku, errors: product.errors.full_messages }
            raise ActiveRecord::Rollback
          end
        end
      rescue StandardError => e
        failed_rows << { row: row_number, sku: sku, errors: [e.message] }
      end

      Result.new(success_count: success_count, skipped_rows: skipped_rows, failed_rows: failed_rows)
    end

    private

    def read_csv
      raw = @file.respond_to?(:read) ? @file.read.force_encoding('UTF-8') : File.read(@file.to_s, encoding: 'UTF-8')
      # Strip UTF-8 BOM if present (common from Excel exports)
      raw.sub!("\xEF\xBB\xBF", '')
      { rows: CSV.parse(raw, headers: true, header_converters: :downcase, skip_blanks: true) }
    rescue CSV::MalformedCSVError => e
      { error: "Invalid CSV: #{e.message}" }
    rescue Encoding::InvalidByteSequenceError
      { error: 'File encoding must be UTF-8. Re-save the file as UTF-8 CSV and try again.' }
    end

    def build_attrs(row, sku, category_cache, uom_cache, hsn_cache)
      # ── Required: HSN code ──────────────────────────────────────────────────
      hsn_code_str = row['hsn_code'].to_s.strip
      return [nil, "hsn_code is required"] if hsn_code_str.blank?

      hsn = hsn_cache[hsn_code_str]
      return [nil, "HSN/SAC code '#{hsn_code_str}' not found in master"] if hsn.nil?

      # ── Category — deferred into per-row transaction via _category_name key ─
      category_name = row['category_name'].to_s.strip
      # Pass the raw name through; category lookup/creation happens inside the
      # wrapping transaction so an orphan is never committed if the product fails.
      pending_category_name = category_name.presence
      uom_symbol = row['uom_symbol'].to_s.strip.downcase
      uom        = uom_symbol.present? ? uom_cache[uom_symbol] : nil
      if uom_symbol.present? && uom.nil?
        return [nil, "Unit of measure '#{row['uom_symbol'].to_s.strip}' not found. " \
                     "Valid symbols: #{uom_cache.keys.map(&:upcase).sort.join(', ')}"]
      end
      return [nil, 'uom_symbol is required'] if uom.nil?

      # ── Numerics ─────────────────────────────────────────────────────────────
      min_order_qty  = parse_integer(row['min_order_qty'],  default: 1)
      purchase_price = parse_decimal(row['purchase_price'])
      weight_kg      = parse_decimal(row['weight_kg'])

      status = row['status'].to_s.strip.downcase.presence || 'active'
      status = 'active' unless Product::VALID_STATUSES.include?(status)

      attrs = {
        sku:                 sku,
        name:                row['name'].to_s.strip,
        hsn_sac_code_id:     hsn.id,
        units_of_measure_id:  uom.id,
        min_order_qty:       min_order_qty,
        status:              status,
        barcode:             row['barcode'].to_s.strip.presence,
        description:         row['description'].to_s.strip.presence,
        image_url:           row['image_url'].to_s.strip.presence,
        purchase_price:      purchase_price,
        weight_kg:           weight_kg,
        # sentinel — resolved inside the product transaction
        _category_name:      pending_category_name
      }.compact

      [attrs, nil]
    end

    def parse_decimal(val, default: nil)
      return default if val.to_s.strip.blank?
      BigDecimal(val.to_s.strip.gsub(',', ''))
    rescue ArgumentError
      default
    end

    def parse_integer(val, default: 1)
      result = val.to_s.strip.to_i
      result > 0 ? result : default
    end
  end
end
