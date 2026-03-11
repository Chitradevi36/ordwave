# frozen_string_literal: true

class BankStatementImportPolicy < ApplicationPolicy
  def index?  = finance_or_admin?
  def show?   = finance_or_admin?
  def create? = finance_or_admin?

  class Scope < Scope
    def resolve
      scope.joins(:bank_account).where(bank_accounts: { organization_id: user.organization_id })
    end
  end

  private

  def finance_or_admin?
    user.admin? || user.finance? || user.accounts? || user.owner?
  end
end
