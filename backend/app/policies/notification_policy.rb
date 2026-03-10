# frozen_string_literal: true

class NotificationPolicy < ApplicationPolicy
  # Users can only interact with their own notifications.

  def index?   = true
  def show?    = own?
  def read?    = own?
  def dismiss? = own?
  def read_all? = true         # scope-guarded — marks only the current user's notifs

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.for_user(user.id).for_org(organization.id)
    end
  end

  private

  def own?
    record.user_id == user.id
  end
end
