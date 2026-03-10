# frozen_string_literal: true

class AuditLogPolicy < ApplicationPolicy
  # Only owners, admins, and managers can view audit logs.
  def index? = manager_above?
  def show?  = manager_above?
end
