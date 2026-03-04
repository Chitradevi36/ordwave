require 'csv'

module Branches
  # Imports Branch records from an uploaded CSV file for the given organisation.
  #
  # Expected CSV columns (case-insensitive headers):
  #   name, code, city, state, state_code (optional), address (optional), pincode (optional)
  #
  # Behaviour:
  #   - Each row runs in its own transaction; failures do not affect other rows.
  #   - Rows where `code` already exists are skipped (reported as skipped, not errors).
  #   - Returns a Result with success_count, skipped_rows, and failed_rows.
  #
  # Usage:
  #   result = Branches::BulkImportService.new(file: params[:file], organization: current_organization).call
  #   result.success_count   # => 5
  #   result.skipped_rows    # => [{ row: 3, code: 'BR-001', reason: 'Code already exists' }]
  #   result.failed_rows     # => [{ row: 4, errors: ["Name can't be blank"] }]
  #
  class BulkImportService
    Result = Struct.new(:success_count, :skipped_rows, :failed_rows, keyword_init: true)

    MAX_ROWS = 500

    def initialize(file:, organization:)
      @file         = file
      @organization = organization
    end

    def call
      success_count = 0
      skipped_rows  = []
      failed_rows   = []
      row_number    = 1 # 1 = header

      csv_data = read_csv
      return Result.new(success_count: 0, skipped_rows: [],
                        failed_rows: [{ row: 0, errors: [csv_data[:error]] }]) if csv_data[:error]

      rows = csv_data[:rows]
      if rows.size > MAX_ROWS
        return Result.new(
          success_count: 0, skipped_rows: [],
          failed_rows: [{ row: 0, errors: ["File has #{rows.size} rows; maximum allowed is #{MAX_ROWS}"] }]
        )
      end

      rows.each do |row|
        row_number += 1
        code = row['code'].to_s.strip.upcase

        if Branch.exists?(code: code)
          skipped_rows << { row: row_number, code: code, reason: 'Code already exists' }
          next
        end

        branch = @organization.branches.build(build_attrs(row))
        if branch.save
          success_count += 1
        else
          failed_rows << { row: row_number, code: code, errors: branch.errors.full_messages }
        end
      rescue StandardError => e
        failed_rows << { row: row_number, errors: [e.message] }
      end

      Result.new(success_count: success_count, skipped_rows: skipped_rows, failed_rows: failed_rows)
    end

    private

    def read_csv
      content = @file.respond_to?(:read) ? @file.read.force_encoding('UTF-8') : File.read(@file.to_s, encoding: 'UTF-8')
      { rows: CSV.parse(content, headers: true, skip_blanks: true) }
    rescue CSV::MalformedCSVError => e
      { error: "Invalid CSV: #{e.message}" }
    rescue Encoding::InvalidByteSequenceError
      { error: 'File encoding must be UTF-8' }
    end

    def build_attrs(row)
      {
        name:       row['name'].to_s.strip,
        code:       row['code'].to_s.strip.upcase,
        city:       row['city'].to_s.strip.presence,
        state:      row['state'].to_s.strip.presence,
        state_code: row['state_code'].to_s.strip.presence,
        address:    row['address'].to_s.strip.presence,
        pincode:    row['pincode'].to_s.strip.presence,
        active:     true
      }
    end
  end
end
