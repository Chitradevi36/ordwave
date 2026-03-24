# ── Document Authorization Policy ────────────────────────────────────────────
# Pundit policy for document access control

class DocumentPolicy < ApplicationPolicy
  # Allow organization members to list documents
  def index?
    user.organization_id == record.organization_id || user.admin?
  end

  # Allow organization members to view document details
  def show?
    user.organization_id == record.organization_id || user.admin?
  end

  # Allow finance team and admins to generate documents
  def generate?
    user.admin? || user_has_role?('finance') || user_has_role?('finance_head')
  end

  # Allow finance heads and admins to batch generate
  def batch_generate?
    user.admin? || user_has_role?('finance_head')
  end

  # Allow any organization member to download their org's documents
  def download?
    user.organization_id == record.organization_id || user.admin?
  end

  # Allow finance team to regenerate documents
  def regenerate?
    user.admin? || user_has_role?('finance') || user_has_role?('finance_head')
  end

  # Allow admins only to archive documents
  def archive?
    user.admin?
  end

  # Allow admins to view statistics
  def statistics?
    user.admin?
  end

  private

  def user_has_role?(role_name)
    return false unless user.respond_to?(:roles)
    user.roles.map(&:role_type).include?(role_name) rescue false
  end

  # Define the scope for querying documents
  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      # Users can see documents from their organization only
      if @user.admin?
        @scope.all
      else
        @scope.where(organization_id: @user.organization_id)
      end
    end

    private

    attr_reader :user, :scope
  end
end
