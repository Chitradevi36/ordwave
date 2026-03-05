class StockTransfer < ApplicationRecord
  STATUSES = %w[draft dispatched partially_received received cancelled].freeze

  TRANSITIONS = {
    'draft'             => %w[dispatched cancelled],
    'dispatched'        => %w[partially_received received cancelled],
    'partially_received'=> %w[received],
    'received'          => [],
    'cancelled'         => []
  }.freeze

  # ── Associations ─────────────────────────────────────────────────────────
  belongs_to :organization
  belongs_to :source_branch,      class_name: 'Branch'
  belongs_to :destination_branch, class_name: 'Branch'
  belongs_to :created_by,         class_name: 'User'
  belongs_to :dispatched_by,      class_name: 'User', optional: true
  belongs_to :received_by,        class_name: 'User', optional: true

  has_many :lines,         class_name: 'StockTransferLine', dependent: :destroy, inverse_of: :stock_transfer
  has_many :audit_logs,    as: :auditable, dependent: :nullify
  has_many :stock_movements, as: :reference, dependent: :nullify

  accepts_nested_attributes_for :lines, allow_destroy: false

  # ── Validations ──────────────────────────────────────────────────────────
  validates :transfer_number, presence: true,
                              uniqueness: { scope: :organization_id }
  validates :transfer_date,   presence: true
  validates :status,          inclusion: { in: STATUSES }
  validates :cancellation_reason, presence: true, if: -> { status == 'cancelled' }
  validate  :source_and_destination_differ

  # ── Callbacks ─────────────────────────────────────────────────────────────
  before_validation :assign_transfer_number, on: :create

  # ── Scopes ────────────────────────────────────────────────────────────────
  scope :not_deleted,      -> { all }   # no hard delete; cancelled is terminal
  scope :for_org,          ->(org)     { where(organization: org) }
  scope :by_status,        ->(s)       { where(status: s) }
  scope :for_source,       ->(bid)     { where(source_branch_id: bid) }
  scope :for_destination,  ->(bid)     { where(destination_branch_id: bid) }
  scope :for_branch,       ->(bid)     { where('source_branch_id = ? OR destination_branch_id = ?', bid, bid) }
  scope :in_date_range,    ->(from, to) {
    scope = all
    scope = scope.where('transfer_date >= ?', from) if from.present?
    scope = scope.where('transfer_date <= ?', to)   if to.present?
    scope
  }
  scope :search_q,         ->(q) {
    term = "%#{sanitize_sql_like(q)}%"
    where('transfer_number ILIKE ?', term)
  }
  scope :recent,           -> { order(created_at: :desc) }

  # ── Status helpers ────────────────────────────────────────────────────────
  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }

  def editable?    = draft?
  def dispatchable? = draft?
  def receivable?  = dispatched? || partially_received?

  def cancellable?
    TRANSITIONS[status].include?('cancelled')
  end

  # Total dispatched quantity across all lines
  def total_qty_dispatched
    lines.sum(:qty_dispatched)
  end

  # Total received + damaged quantity across all lines
  def total_qty_accounted
    lines.sum(:qty_received) + lines.sum(:qty_damaged)
  end

  private

  def assign_transfer_number
    return if transfer_number.present?

    max = StockTransfer.where(organization_id: organization_id).maximum(:id).to_i
    self.transfer_number = "TRF-#{organization_id.to_s.rjust(4, '0')}-#{(max + 1).to_s.rjust(6, '0')}"
  end

  def source_and_destination_differ
    return if source_branch_id.blank? || destination_branch_id.blank?
    errors.add(:destination_branch, 'must differ from source branch') if
      source_branch_id == destination_branch_id
  end
end
