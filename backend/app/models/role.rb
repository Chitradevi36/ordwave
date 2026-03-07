class Role < ApplicationRecord
  NAMES = %w[owner admin manager sales_rep warehouse_staff accountant driver].freeze

  # Associations
  has_many :memberships

  # Validations
  validates :name, presence: true, uniqueness: true, inclusion: { in: NAMES }

  # Scopes
  scope :active, -> { all } # Roles are system-wide, no deactivation needed

  def self.fetch!(name)
    role_name = name.to_s.strip
    raise ArgumentError, 'Role name is required' if role_name.blank?
    raise ArgumentError, "Invalid role: #{role_name}" unless NAMES.include?(role_name)

    find_by(name: role_name) ||
      create!(name: role_name, description: "#{role_name.humanize} role")
  rescue ActiveRecord::RecordNotUnique
    # Race condition: another process created it between our find and create
    find_by!(name: role_name)
  rescue ActiveRecord::RecordInvalid
    find_by!(name: role_name) || raise
  end

  def owner?     = name == 'owner'
  def admin?     = name == 'admin'
  def manager?   = name == 'manager'
  def sales_rep? = name == 'sales_rep'
  def driver?    = name == 'driver'
end
