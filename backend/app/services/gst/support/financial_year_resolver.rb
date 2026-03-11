# frozen_string_literal: true

module Gst
  module Support
    # Resolves or creates the FinancialYear for a given organization and date/month-year.
    #
    # Usage:
    #   resolver = Gst::Support::FinancialYearResolver.new(organization: org)
    #   fy = resolver.resolve_for_date(Date.today)
    #   fy = resolver.resolve_for_period(month: 9, year: 2025)
    #   fy = resolver.find_or_create_for_date!(Date.today)
    #
    class FinancialYearResolver
      class ResolutionError < StandardError; end

      # India default: FY starts April 1
      DEFAULT_START_MONTH = 4
      DEFAULT_START_DAY   = 1

      def initialize(organization:)
        @organization = organization
      end

      # Returns the FinancialYear for a given date. Returns nil if none exists.
      def resolve_for_date(date)
        date = date.to_date
        FinancialYear.for_org(@organization).for_date(date).first
      end

      # Returns the FinancialYear that covers the given calendar month+year.
      def resolve_for_period(month:, year:)
        date = Date.new(year, month, 1)
        resolve_for_date(date)
      end

      # Finds existing or creates a FinancialYear for the given date.
      # Raises ResolutionError if FY is closed/archived and edits are attempted.
      def find_or_create_for_date!(date)
        date = date.to_date
        existing = resolve_for_date(date)
        return existing if existing.present?

        build_and_save_fy_for_date!(date)
      end

      def find_or_create_for_period!(month:, year:)
        find_or_create_for_date!(Date.new(year, month, 1))
      end

      # Returns all FYs for the organization, newest first
      def list_financial_years
        FinancialYear.for_org(@organization).recent
      end

      # Human-readable code from a fiscal start year, e.g. 2025 → "FY2025-26"
      def self.code_for_fiscal_start_year(fiscal_start_year)
        "FY#{fiscal_start_year}-#{(fiscal_start_year + 1).to_s.last(2)}"
      end

      # Given a calendar date, returns the fiscal start year
      # e.g. April  1 2025 → 2025
      #       March 31 2025 → 2024
      def self.fiscal_start_year_for_date(date, start_month: DEFAULT_START_MONTH)
        date = date.to_date
        date.month >= start_month ? date.year : date.year - 1
      end

      private

      def build_and_save_fy_for_date!(date)
        start_month = DEFAULT_START_MONTH
        start_day   = DEFAULT_START_DAY

        fiscal_start_year = self.class.fiscal_start_year_for_date(date, start_month: start_month)
        start_date = Date.new(fiscal_start_year, start_month, start_day)
        end_date   = Date.new(fiscal_start_year + 1, start_month, start_day) - 1

        code  = self.class.code_for_fiscal_start_year(fiscal_start_year)
        label = "#{Date::ABBR_MONTHNAMES[start_month]} #{fiscal_start_year} – " \
                "#{Date::ABBR_MONTHNAMES[start_month - 1].presence || 'Mar'} #{fiscal_start_year + 1}"

        FinancialYear.create!(
          organization:    @organization,
          code:            code,
          label:           label,
          start_date:      start_date,
          end_date:        end_date,
          starts_on_month: start_month,
          starts_on_day:   start_day,
          status:          'open'
        )
      rescue ActiveRecord::RecordNotUnique
        # Race condition guard — another process created it; just fetch it
        FinancialYear.for_org(@organization).find_by!(code: self.class.code_for_fiscal_start_year(date.month >= DEFAULT_START_MONTH ? date.year : date.year - 1))
      end
    end
  end
end
