class StockMovement < ApplicationRecord
  # Granular types introduced by the Inventory Ledger module.
  # Legacy types (purchase / sale / adjustment / return / reversal) are kept for
  # backward-compat with existing rows; new code uses the fine-grained set below.
  MOVEMENT_TYPES = %w[
    purchase_posted
    purchase_cancelled
    sale_reserved
    sale_unreserved
    sale_dispatched
    sale_delivered
    sale_cancelled
    return_received
    transfer_in
    transfer_out
    adjustment_in
    adjustment_out
    purchase
    sale
    adjustment
    return
    reversal
  ].freeze

  DIRECTIONS = %w[in out].freeze

  # Movement-type → balance impact maps (used by Inventory::PostMovement)
  ON_HAND_IN_TYPES  = %w[purchase_posted return_received transfer_in adjustment_in purchase].freeze
  ON_HAND_OUT_TYPES = %w[purchase_cancelled sale_dispatched sale_delivered transfer_out adjustment_out reversal].freeze
  RESERVE_IN_TYPES  = %w[sale_reserved].freeze
  RESERVE_OUT_TYPES = %w[sale_unreserved sale_dispatched sale_delivered sale_cancelled].freeze

  # ── Associations ─────────────────────────────────────────────────────────────
  belongs_to :organization
  belongs_to :branch
  belongs_to :product
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :reference,  polymorphic: true,  optional: true

  # ── Validations ──────────────────────────────────────────────────────────────
  validates :movement_type, inclusion: { in: MOVEMENT_TYPES }
  validates :direction,     inclusion: { in: DIRECTIONS }
  validates :qty,           numericality: { greater_than: 0 }
  validates :occurred_at,   presence: true

  # ── Immutability — ledger rows must never be modified or deleted ──────────────
  before_update  { raise ActiveRecord::ReadOnlyRecord, 'StockMovement records are immutable' }
  before_destroy { raise ActiveRecord::ReadOnlyRecord, 'StockMovement records cannot be deleted' }

  # ── Callbacks ────────────────────────────────────────────────────────────────
  before_validation :set_occurred_at, on: :create

  # ── Scopes ───────────────────────────────────────────────────────────────────
  scope :for_org,       ->(org)     { where(organization: org) }
  scope :for_branch,    ->(branch)  { where(branch: branch) }
  scope :for_product,   ->(product) { where(product: product) }
  scope :inbound,       ->          { where(direction: 'in') }
  scope :outbound,      ->          { where(direction: 'out') }
  scope :by_type,       ->(t)       { where(movement_type: t) }
  scope :for_reference, ->(ref)     { where(reference: ref) }
  scope :in_date_range, ->(from, to) {
    scope = all
    scope = scope.where('occurred_at >= ?', from) if from.present?
    scope = scope.where('occurred_at <= ?', to)   if to.present?
    scope
  }
  scope :recent,        ->          { order(occurred_at: :desc) }

  # ── Helpers ───────────────────────────────────────────────────────────────────
  # Signed delta this movement applies to qty_on_hand on the balance row
  def on_hand_delta
    if ON_HAND_IN_TYPES.include?(movement_type)
      qty
    elsif ON_HAND_OUT_TYPES.include?(movement_type)
      -qty
    else
      0
    end
  end

  # Signed delta this movement applies to qty_reserved on the balance row
  def reserved_delta
    if RESERVE_IN_TYPES.include?(movement_type)
      qty
    elsif RESERVE_OUT_TYPES.include?(movement_type)
      -qty
    else
      0
    end
  end

  private

  def set_occurred_at
    self.occurred_at ||= Time.current
  end
end
