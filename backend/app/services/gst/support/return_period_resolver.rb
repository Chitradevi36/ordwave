# frozen_string_literal: true

module Gst
  module Support
    # Resolves or creates a GstReturnPeriod for a given organization, branch,
    # month, year, and return_type.
    #
    # Usage:
    #   resolver = Gst::Support::ReturnPeriodResolver.new(
    #     organization: org, branch: branch
    #   )
    #   period = resolver.find_or_create!(month: 9, year: 2025, return_type: 'gstr1')
    #
    class ReturnPeriodResolver
      Result = Struct.new(:period, :created, keyword_init: true) do
        def created?; created; end
      end

      def initialize(organization:, branch: nil)
        @organization = organization
        @branch       = branch
      end

      # Finds or creates the GstReturnPeriod.
      # Returns a Result struct.
      def find_or_create!(month:, year:, return_type:)
        validate_return_type!(return_type)

        period = find(month: month, year: year, return_type: return_type)
        if period.present?
          Result.new(period: period, created: false)
        else
          period = create!(month: month, year: year, return_type: return_type)
          Result.new(period: period, created: true)
        end
      end

      def find(month:, year:, return_type:)
        GstReturnPeriod.find_by(
          organization_id: @organization.id,
          branch_id:       @branch&.id,
          month:           month,
          year:            year,
          return_type:     return_type
        )
      end

      # For a given period, returns the GSTR-1 period as well (useful for cross-reference)
      def find_gstr1_period(month:, year:)
        find(month: month, year: year, return_type: 'gstr1')
      end

      private

      def validate_return_type!(return_type)
        unless GstReturnPeriod::RETURN_TYPES.include?(return_type)
          raise ArgumentError, "Invalid return_type '#{return_type}'. " \
                               "Must be one of: #{GstReturnPeriod::RETURN_TYPES.join(', ')}"
        end
      end

      def create!(month:, year:, return_type:)
        fy_resolver = Gst::Support::FinancialYearResolver.new(organization: @organization)
        fy          = fy_resolver.find_or_create_for_period!(month: month, year: year)

        period_start = Date.new(year, month, 1)
        period_end   = period_start.end_of_month

        GstReturnPeriod.create!(
          organization:         @organization,
          branch:               @branch,
          financial_year:       fy,
          financial_year_label: fy.code,
          month:                month,
          year:                 year,
          period_start_on:      period_start,
          period_end_on:        period_end,
          return_type:          return_type,
          status:               'draft'
        )
      rescue ActiveRecord::RecordNotUnique
        # Race condition guard
        find(month: month, year: year, return_type: return_type)
      end
    end
  end
end
