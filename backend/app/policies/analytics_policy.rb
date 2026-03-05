# frozen_string_literal: true

class AnalyticsPolicy < ApplicationPolicy
  # All authenticated org members can read analytics.
  # The controller further restricts sales_rep data to their own records.
  def read?   = member?

  # Only managers and above can export CSVs
  def export? = manager_above?
end
