class Membership < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :organization
  belongs_to :branch
  belongs_to :role

  # Validations
  validates :user_id, uniqueness: { scope: [:organization_id, :branch_id],
                                    message: 'already has a membership in this branch' }
  validates :user, :organization, :branch, :role, presence: true

  # Scopes
  scope :active,      -> { where(active: true, deleted_at: nil) }
  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :for_org,     ->(org)    { where(organization: org) }
  scope :for_branch,  ->(branch) { where(branch: branch) }
  scope :for_role,    ->(role)   { where(role: role) }
  scope :by_status,   ->(status) { where(status: status) }

  def soft_delete!
    update!(deleted_at: Time.current, active: false)
  end

  def deleted?
    deleted_at.present?
  end
end
