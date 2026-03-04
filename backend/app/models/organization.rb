class Organization < ApplicationRecord
  # Note: plan is a denormalized field that mirrors the owner's user plan
  # The authoritative plan is stored on the User model
  PLANS = User::PLANS

  # Associations
  has_many :branches,    dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :users,       through: :memberships

  # Validations
  validates :name,          presence: true, length: { maximum: 100 }
  validates :slug,          presence: true, uniqueness: true,
                            format: { with: /\A[a-z0-9\-]+\z/, message: 'only lowercase letters, numbers, and hyphens' }
  validates :plan,          presence: true, inclusion: { in: PLANS }, allow_blank: true
  validates :contact_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :gst_number,    format: { with: /\A[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}\z/ },
                            allow_blank: true

  # Scopes
  scope :active, -> { where(active: true) }

  # Callbacks
  before_validation :generate_slug, on: :create, if: -> { slug.blank? }

  private

  def generate_slug
    self.slug = name.to_s.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/^-|-$/, '') if name.present?
  end
end
