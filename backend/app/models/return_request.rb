class ReturnRequest < ApplicationRecord
  SOURCE_TYPES = %w[delivery order manual].freeze
  STATUSES = %w[draft submitted qc_in_progress qc_completed credit_note_issued cancelled].freeze

  TRANSITIONS = {
    'draft'              => %w[submitted cancelled],
    'submitted'          => %w[qc_in_progress cancelled],
    'qc_in_progress'     => %w[qc_completed],
    'qc_completed'       => %w[credit_note_issued],
    'credit_note_issued' => [],
    'cancelled'          => []
  }.freeze

  CONDITIONS_REPORTED = %w[resalable damaged expired unknown].freeze
  REASON_CODES        = %w[customer_refused quality_issue expired short_supply other].freeze

  # ── Associations ───────────────────────────────────────────────────────────
  belongs_to :organization
  belongs_to :branch
  belongs_to :customer
  belongs_to :created_by, class_name: 'User'

  has_many :lines,        class_name: 'ReturnLine',    dependent: :destroy, inverse_of: :return_request
  has_many :qc_items,     through: :lines,             source: :qc_item
  has_many :stock_movements, as: :reference,           dependent: :nullify
  has_many :audit_logs,   as: :auditable,              dependent: :nullify
  has_one  :credit_note,                               dependent: :nullify

  accepts_nested_attributes_for :lines, allow_destroy: true

  # ── Validations ────────────────────────────────────────────────────────────
  validates :return_number, presence: true,
                            uniqueness: { scope: :organization_id }
  validates :status,       inclusion: { in: STATUSES }
  validates :source_type,  inclusion: { in: SOURCE_TYPES }
  validates :return_date,  presence: true
  validates :cancellation_reason, presence: true, if: -> { status == 'cancelled' }

  # ── Callbacks ──────────────────────────────────────────────────────────────
  before_validation :assign_return_number, on: :create

  # ── Scopes ─────────────────────────────────────────────────────────────────
  scope :not_deleted,   -> { where(deleted_at: nil) }
  scope :for_org,       ->(org) { where(organization: org) }
  scope :by_status,     ->(s)   { where(status: s) }
  scope :by_customer,   ->(cid) { where(customer_id: cid) }
  scope :by_branch,     ->(bid) { where(branch_id: bid) }
  scope :recent,        -> { order(created_at: :desc) }
  scope :in_date_range, ->(from_d, to_d) {
    scope = all
    scope = scope.where('return_requests.return_date >= ?', from_d) if from_d.present?
    scope = scope.where('return_requests.return_date <= ?', to_d)   if to_d.present?
    scope
  }
  scope :search_q, ->(q) {
    term = "%#{sanitize_sql_like(q)}%"
    joins(:customer)
      .where('return_requests.return_number ILIKE :t OR customers.name ILIKE :t', t: term)
  }

  # ── Status helpers ─────────────────────────────────────────────────────────
  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }

  def editable?     = draft?
  def cancellable?  = TRANSITIONS[status].include?('cancelled')
  def qc_startable? = submitted?
  def qc_completable? = qc_in_progress?
  def creditable?   = qc_completed?

  # ── State machine ──────────────────────────────────────────────────────────
  def transition_to!(new_status, reason: nil, actor: nil)
    allowed = TRANSITIONS.fetch(status, [])
    unless allowed.include?(new_status.to_s)
      raise ActiveRecord::RecordInvalid.new(self),
            "Cannot transition from '#{status}' to '#{new_status}'"
    end

    timestamp_col = {
      'submitted'          => :submitted_at,
      'qc_completed'       => :qc_completed_at,
      'credit_note_issued' => :credit_note_issued_at,
      'cancelled'          => :cancelled_at
    }[new_status.to_s]

    attrs = { status: new_status }
    attrs[timestamp_col] = Time.current if timestamp_col
    attrs[:cancellation_reason] = reason if new_status.to_s == 'cancelled'

    update!(attrs)
  end

  private

  def assign_return_number
    return if return_number.present?

    max = ReturnRequest.where(organization_id: organization_id).maximum(:id).to_i
    self.return_number = "RET-#{organization_id.to_s.rjust(4, '0')}-#{(max + 1).to_s.rjust(6, '0')}"
  end
end
