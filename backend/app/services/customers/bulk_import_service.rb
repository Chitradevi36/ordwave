require 'csv'

module Customers
  # Imports Customer records from an uploaded CSV file for the given organisation.
  #
  # Expected CSV columns (case-insensitive headers):
  #   name*, code*, channel, tier, customer_type, status, phone*, email,
  #   gstin, pan, credit_limit, credit_days, credit_block_rule, opening_balance,
  #   visit_frequency, branch_code*, route_code, tags
  #  (* required)
  #
  # Behaviour:
  #   - Each row runs in its own transaction; failures do not affect other rows.
  #   - Rows where (code + organization) already exists are skipped.
  #   - branch_code is resolved to branch_id within the organisation.
  #   - route_code is resolved to route_id within the organisation.
  #   - tags is a comma-separated string (e.g. "regular,vip").
  #   - A CreditAccount is created automatically for each imported customer.
  #
  # Usage:
  #   result = Customers::BulkImportService.new(file: params[:file], organization: org).call
  #   result.success_count
  #   result.skipped_rows   # [{ row: 3, code: 'CUST-001', reason: '...' }]
  #   result.failed_rows    # [{ row: 4, errors: ["Name can't be blank"] }]
  #
  class BulkImportService
    Result = Struct.new(:success_count, :skipped_rows, :failed_rows, keyword_init: true)

    MAX_ROWS = 2_000

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
      return Result.new(success_count: 0, skipped_rows: [],
                        failed_rows: [{ row: 0, errors: [csv_data[:error]] }]) if csv_data[:error]

      rows = csv_data[:rows]
      if rows.size > MAX_ROWS
        return Result.new(
          success_count: 0, skipped_rows: [],
          failed_rows: [{ row: 0, errors: ["File has #{rows.size} rows; maximum allowed is #{MAX_ROWS}"] }]
        )
      end

      # Pre-cache branch and route lookups to avoid N+1
      branch_cache = @organization.branches.not_deleted.index_by(&:code)
      route_cache  = Route.where(organization: @organization).index_by(&:code)

      rows.each do |row|
        row_number += 1
        code = row['code'].to_s.strip

        if Customer.not_deleted.exists?(organization: @organization, code: code)
          skipped_rows << { row: row_number, code: code, reason: 'Customer code already exists in this organisation' }
          next
        end

        attrs, error = build_attrs(row, branch_cache, route_cache)
        if error
          failed_rows << { row: row_number, code: code, errors: [error] }
          next
        end

        ActiveRecord::Base.transaction do
          customer = Customer.new(attrs.merge(organization: @organization))
          if customer.save
            create_credit_account(customer)
            success_count += 1
          else
            failed_rows << { row: row_number, code: code, errors: customer.errors.full_messages }
            raise ActiveRecord::Rollback
          end
        end
      rescue StandardError => e
        failed_rows << { row: row_number, code: code, errors: [e.message] }
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

    def build_attrs(row, branch_cache, route_cache)
      branch_code = row['branch_code'].to_s.strip.upcase
      branch      = branch_cache[branch_code]
      return [nil, "Branch code '#{branch_code}' not found in this organisation"] if branch_code.present? && branch.nil?
      return [nil, "branch_code is required"]                                      if branch.nil?

      route = nil
      if (route_code = row['route_code'].to_s.strip.upcase).present?
        route = route_cache[route_code]
        return [nil, "Route code '#{route_code}' not found in this organisation"] if route.nil?
      end

      tags = row['tags'].to_s.split(',').map(&:strip).reject(&:blank?)

      # Phone is required for each customer import and must be a 10-digit number
      phone_val = row['phone'].to_s.strip.presence
      return [nil, "phone is required and must be a 10-digit number"] unless phone_val && phone_val.match?(/\A[0-9]{10}\z/)

      attrs = {
        name:               row['name'].to_s.strip,
        code:               row['code'].to_s.strip,
        channel:            row['channel'].to_s.strip.presence,
        tier:               row['tier'].to_s.strip.presence,
        customer_type:      row['customer_type'].to_s.strip.presence,
        status:             row['status'].to_s.strip.presence || 'active',
        phone:              phone_val,
        email:              row['email'].to_s.strip.downcase.presence,
        gstin:              row['gstin'].to_s.strip.upcase.presence,
        pan:                row['pan'].to_s.strip.upcase.presence,
        credit_limit:       parse_decimal(row['credit_limit'], default: 0),
        credit_days:        row['credit_days'].to_s.strip.to_i,
        credit_block_rule:  row['credit_block_rule'].to_s.strip.presence || 'none',
        opening_balance:    parse_decimal(row['opening_balance'], default: 0),
        visit_frequency:    row['visit_frequency'].to_s.strip.presence,
        branch_id:          branch.id,
        route_id:           route&.id,
        tag_list:           tags
      }.compact

      [attrs, nil]
    end

    def create_credit_account(customer)
      CreditAccount.create!(
        customer:         customer,
        organization:     @organization,
        branch_id:        customer.branch_id,
        credit_limit:     customer.credit_limit || 0,
        current_balance:  customer.opening_balance || 0,
        available_credit: [(customer.credit_limit || 0) - (customer.opening_balance || 0), 0].max,
        overdue_amount:   0,
        overdue_days:     0
      )
    end

    def parse_decimal(val, default: nil)
      return default if val.to_s.strip.blank?

      BigDecimal(val.to_s.strip)
    rescue ArgumentError
      default
    end
  end
end
