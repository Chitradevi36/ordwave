# frozen_string_literal: true

class BankAccountPolicy < ApplicationPolicy
  def index?   = finance_or_admin?
  def show?    = finance_or_admin?
  def create?  = admin?
  def update?  = admin?
  def destroy? = false   # soft-deactivate only via update

  class Scope < Scope
    def resolve
      scope.where(organization: user.organization)
    end
  end

  private

  def finance_or_admin?
    user.admin? || user.finance? || user.accounts? || user.owner?
  end

  def admin?
    user.admin? || user.owner?
  end
end
