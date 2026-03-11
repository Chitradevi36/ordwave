# frozen_string_literal: true

class BankTransactionPolicy < ApplicationPolicy
  def index?         = finance_or_admin?
  def show?          = finance_or_admin?
  def confirm_match? = finance_or_admin?
  def mark_as_advance? = finance_or_admin?
  def ignore?        = finance_or_admin?
  def retry_match?   = finance_or_admin?

  class Scope < Scope
    def resolve
      scope.joins(:bank_account)
           .where(bank_accounts: { organization_id: user.organization_id })
    end
  end

  private

  def finance_or_admin?
    user.admin? || user.finance? || user.accounts? || user.owner?
  end
end
