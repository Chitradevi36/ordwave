class Role < ApplicationRecord
  NAMES = %w[owner admin manager sales_rep warehouse_staff accountant driver].freeze

  # Associations
  has_many :memberships

  # Validations
  validates :name, presence: true, uniqueness: true, inclusion: { in: NAMES }

  # Scopes
  scope :active, -> { all } # Roles are system-wide, no deactivation needed

  def owner?     = name == 'owner'
  def admin?     = name == 'admin'
  def manager?   = name == 'manager'
  def sales_rep? = name == 'sales_rep'
  def driver?    = name == 'driver'
end
