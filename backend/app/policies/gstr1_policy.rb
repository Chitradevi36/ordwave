# frozen_string_literal: true

# Policy for compliance/GST actions (used via `authorize :gstr1, :preview?`).
# Pundit resolves :gstr1 to Gstr1Policy.
class Gstr1Policy < ApplicationPolicy
  # Any org member may view the preview.
  def preview? = member?

  # Managers and above may download the official GST portal JSON.
  def export?  = manager_above?

  # Managers and above may view past export records.
  def index?   = manager_above?
  def show?    = manager_above?
end
