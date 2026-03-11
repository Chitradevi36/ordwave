# frozen_string_literal: true

class RetailerRiskSnapshotPolicy < ApplicationPolicy
  # Any org member can view risk profiles
  def show?   = membership_present?
  def index?  = membership_present?
  def create? = manager_or_above?

  private

  def membership_present?
    user.present? && organization.present? &&
      user.memberships.active.exists?(organization: organization)
  end

  def manager_or_above?
    membership_present? &&
      user.role_in(organization)&.name&.in?(%w[owner admin manager])
  end
end
