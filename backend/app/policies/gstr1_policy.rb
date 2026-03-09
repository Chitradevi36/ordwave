# frozen_string_literal: true

# Policy for compliance/GST actions (used via `authorize :gstr1, :preview?`).
# Pundit resolves :gstr1 to Gstr1Policy.
class Gstr1Policy < ApplicationPolicy
  def preview? = manager_above?
  def export?  = manager_above?
end
