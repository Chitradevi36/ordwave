class ProductCategory < ApplicationRecord
  VALID_STATUSES = %w[active inactive].freeze

  belongs_to :organization
  has_many   :products, dependent: :restrict_with_error

  # Validations
  validates :name,    presence: true, length: { maximum: 100 }
  validates :code,    format: { with: /\A[A-Z0-9\-_]+\z/, message: 'only uppercase letters, numbers, hyphens and underscores' }, allow_blank: true
  validates :active,  inclusion: { in: [true, false] }

  # Scopes
  scope :active,      -> { where(active: true, deleted_at: nil) }
  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :for_org,     ->(org_id) { where(organization_id: org_id) }

  def soft_delete!
    update!(deleted_at: Time.current, active: false)
  end

  def deleted?
    deleted_at.present?
  end
end
