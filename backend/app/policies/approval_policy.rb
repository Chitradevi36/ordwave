# frozen_string_literal: true

class ApprovalPolicy < ApplicationPolicy
  # Only owners, admins, and managers can view/act on approvals.
  def index?    = manager_above?
  def show?     = manager_above?
  def create?   = manager_above?
  def update?   = manager_above?
end
