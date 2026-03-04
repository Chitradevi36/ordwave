require 'csv'

module HsnSacCodes
  # Imports HsnSacCode records from an uploaded CSV file.
  #
  # Expected CSV columns (case-insensitive headers):
  #   code, code_type, description, gst_rate, effective_from, chapter (optional)
  #
  # Behaviour:
  #   - Each row is processed in its own transaction.
  #   - Duplicate (code + effective_from) rows are skipped (not errors).
  #   - Rows with blank code/gst_rate/effective_from are recorded as failures.
  #   - Returns a Result with success_count and failed_rows.
  #
  # Usage:
  #   result = HsnSacCodes::BulkImportService.new(file: params[:file]).call
  #   result.success_count  # => 42
  #   result.failed_rows    # => [{ row: 3, errors: ["Code can't be blank"] }]
  #
  class BulkImportService
    Result = Struct.new(:success_count, :failed_rows, keyword_init: true)

    MAX_ROWS = 2_000

    def initialize(file:)
      @file = file
    end

    def call
      success_count = 0
      failed_rows   = []
      row_number    = 1  # 1-based (row 1 = header)

      csv_data = read_csv
      return Result.new(success_count: 0,
                        failed_rows: [{ row: 0, errors: [csv_data[:error]] }]) if csv_data[:error]

      rows = csv_data[:rows]
      if rows.size > MAX_ROWS
        return Result.new(
          success_count: 0,
          failed_rows: [{ row: 0, errors: ["File has #{rows.size} rows; maximum allowed is #{MAX_ROWS}"] }]
        )
      end

      rows.each do |row|
        row_number += 1
        attrs = build_attrs(row)

        # Skip true duplicates silently
        if HsnSacCode.exists?(code: attrs[:code], effective_from: attrs[:effective_from])
          next
        end

        record = HsnSacCode.new(attrs)

        if record.valid?
          record.save!
          success_count += 1
        else
          failed_rows << { row: row_number, errors: record.errors.full_messages }
        end
      rescue StandardError => e
        failed_rows << { row: row_number, errors: [e.message] }
      end

      Result.new(success_count: success_count, failed_rows: failed_rows)
    end

    private

    def read_csv
      content = if @file.respond_to?(:read)
                  @file.read.force_encoding('UTF-8')
                else
                  File.read(@file.to_s, encoding: 'UTF-8')
                end

      table = CSV.parse(content, headers: true, skip_blanks: true)
      { rows: table }
    rescue CSV::MalformedCSVError => e
      { error: "Invalid CSV: #{e.message}" }
    rescue Encoding::InvalidByteSequenceError
      { error: 'File encoding must be UTF-8' }
    end

    def build_attrs(row)
      {
        code:           row['code'].to_s.strip.upcase,
        code_type:      row['code_type'].to_s.strip.upcase.presence || 'HSN',
        description:    row['description'].to_s.strip.presence,
        chapter:        row['chapter'].to_s.strip.presence,
        gst_rate:       parse_decimal(row['gst_rate']),
        effective_from: parse_date(row['effective_from']),
        active:         true
      }
    end

    def parse_decimal(val)
      return nil if val.to_s.strip.blank?

      BigDecimal(val.to_s.strip)
    rescue ArgumentError
      nil
    end

    def parse_date(val)
      return nil if val.to_s.strip.blank?

      Date.parse(val.to_s.strip)
    rescue ArgumentError
      nil
    end
  end
end
