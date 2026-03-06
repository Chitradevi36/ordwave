class Route < ApplicationRecord
  # Associations
  belongs_to :organization
  belongs_to :branch
  belongs_to :vehicle,        optional: true
  belongs_to :default_driver, class_name: 'User', optional: true
  has_many   :customers, dependent: :nullify
  has_many   :delivery_trips

  # Validations
  validates :name, presence: true, length: { maximum: 100 }
  validates :code, presence: true,
                   uniqueness: { scope: :branch_id, message: 'has already been taken for this branch' },
                   format: { with: /\A[A-Z0-9\-]+\z/, message: 'only uppercase letters, numbers, and hyphens' }
  validates :branch,        presence: true
  validates :organization,  presence: true

  # Scopes
  scope :active, -> { where(active: true) }
  scope :for_org, ->(org_id) { where(organization_id: org_id) }
end
