# frozen_string_literal: true

class SupplierDebitNotePolicy < ApplicationPolicy
  def index?  = member?
  def show?   = member? && within_org?
  def create? = manager_above? && within_org?
  def update? = manager_above? && within_org? && record.draft?
  def issue?  = manager_above? && within_org? && record.draft?
  def void?   = owner_or_admin? && within_org? && record.issued?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.not_deleted.for_org(organization)
    end
  end

  private

  def within_org?
    record.organization_id == @organization.id
  end
end
