class Supplier < ApplicationRecord
  STATUSES          = %w[active inactive blacklisted].freeze
  PAYMENT_TERMS     = [0, 7, 15, 30, 45, 60].freeze
  GSTIN_REGEX       = /\A[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]\z/
  PAN_REGEX         = /\A[A-Z]{5}[0-9]{4}[A-Z]\z/
  CODE_REGEX        = /\A[A-Za-z0-9\-_]+\z/
  BANK_IFSC_REGEX   = /\A[A-Z]{4}0[A-Z0-9]{6}\z/

  # ── Associations ──────────────────────────────────────────────────────────
  belongs_to :organization

  has_many :supplier_products,   dependent: :destroy
  has_many :products,             through: :supplier_products
  has_many :purchase_invoices,    dependent: :restrict_with_error
  has_many :audit_logs,           as: :auditable, dependent: :nullify

  # ── Validations ───────────────────────────────────────────────────────────
  validates :name,   presence: true, length: { maximum: 200 }
  validates :code,   presence: true,
                     format: { with: CODE_REGEX, message: 'only letters, numbers, hyphens, and underscores' },
                     uniqueness: {
                       scope:      :organization_id,
                       conditions: -> { where(deleted_at: nil) },
                       message:    'has already been taken for this organization'
                     }
  validates :phone,  presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :payment_terms_days,
            inclusion: { in: PAYMENT_TERMS, message: "must be one of #{PAYMENT_TERMS.join(', ')}" }
  validates :credit_limit,
            numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :gstin,
            format: { with: GSTIN_REGEX, message: 'is not a valid GSTIN' },
            allow_blank: true
  validates :pan,
            format: { with: PAN_REGEX, message: 'is not a valid PAN' },
            allow_blank: true
  validates :bank_ifsc,
            format: { with: BANK_IFSC_REGEX, message: 'is not a valid IFSC code' },
            allow_blank: true

  # ── Scopes ────────────────────────────────────────────────────────────────
  scope :not_deleted,      -> { where(deleted_at: nil) }
  scope :active,           -> { not_deleted.where(status: 'active') }
  scope :by_status,        ->(s) { where(status: s) }
  scope :for_org,          ->(org) { where(organization: org) }
  scope :search_query,     lambda { |q|
    term = "%#{q.strip}%"
    where(
      'suppliers.name ILIKE :q OR suppliers.code ILIKE :q OR suppliers.gstin ILIKE :q OR suppliers.phone ILIKE :q',
      q: term
    )
  }

  # ── Instance helpers ──────────────────────────────────────────────────────
  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }

  def soft_delete!
    update!(deleted_at: Time.current, status: 'inactive')
  end

  def deleted?
    deleted_at.present?
  end

  def blacklist!
    update!(status: 'blacklisted')
  end

  def activate!
    update!(status: 'active')
  end

  # Block deletion if supplier has open purchase invoices (stub — extend when
  # PurchaseInvoice module is added).
  def deletable?
    # Placeholder: always deletable until purchase invoice associations exist.
    true
  end

  def deletion_blockers
    # Returns human-readable reasons if not deletable.
    []
  end
end
