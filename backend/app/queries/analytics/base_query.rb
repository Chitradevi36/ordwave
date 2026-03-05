# frozen_string_literal: true
#
# Analytics::BaseQuery
# Shared helpers for all analytics query objects.
#
module Analytics
  class BaseQuery
    MTD_BEGIN = -> { Date.current.beginning_of_month }
    TODAY     = -> { Date.current }

    def initialize(organization:, branch_id: nil)
      @organization = organization
      @branch_id    = branch_id.presence&.to_i
    end

    private

    attr_reader :organization, :branch_id

    def org_id
      organization.id
    end

    # Applies organization (and optionally branch) scope to an AR relation.
    def org_scope(relation, org_col: :organization_id, branch_col: :branch_id)
      relation = relation.where(org_col => org_id)
      relation = relation.where(branch_col => branch_id) if branch_id.present?
      relation
    end

    # Converts param that may be String/Date to a Date, falling back to default.
    def parse_date(val, default)
      val.present? ? Date.parse(val.to_s) : default
    rescue ArgumentError
      default
    end

    def pct(numerator, denominator)
      return 0.0 if denominator.nil? || denominator.zero?
      ((numerator.to_f / denominator.to_f) * 100.0).round(1)
    end
  end
end
