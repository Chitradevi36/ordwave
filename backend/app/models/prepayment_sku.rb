class PrepaymentSku < ApplicationRecord
  belongs_to :organization
  belongs_to :branch,     optional: true
  belongs_to :product
  belongs_to :created_by, class_name: 'User'

  validates :reason,         presence: true
  validates :effective_from, presence: true
  validates :product_id,     presence: true

  # Uniqueness enforced at the DB level too (partial unique index)
  validates :product_id, uniqueness: {
    scope:   [:organization_id, :branch_id],
    message: "already has an active prepayment requirement",
    conditions: -> { where(active: true) }
  }, if: :active?

  scope :active,       -> { where(active: true) }
  scope :not_deleted,  -> { all }
  scope :for_org,      ->(org)    { where(organization: org) }
  scope :for_branch,   ->(branch) { where(branch: branch) }
  scope :for_product,  ->(prod)   { where(product: prod) }
  scope :effective,    ->(date = Date.current) { active.where(effective_from: ..date) }

  def deactivate!
    update!(active: false)
  end
end
