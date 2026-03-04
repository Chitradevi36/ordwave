class CreditAccount < ApplicationRecord
  OVERDUE_BUCKETS = {
    'current'  => 0..0,
    'mild'     => 1..14,
    'moderate' => 15..29,
    'serious'  => 30..59,
    'critical' => 60..Float::INFINITY,
  }.freeze

  belongs_to :customer
  belongs_to :organization
  belongs_to :branch

  has_many :limit_change_requests,
           class_name:  'CreditLimitChangeRequest',
           foreign_key: :credit_account_id,
           dependent:   :destroy

  has_many :audit_logs, as: :auditable, dependent: :destroy

  validates :credit_limit,     numericality: { greater_than_or_equal_to: 0 }
  validates :current_balance,  numericality: true
  validates :available_credit, numericality: true
  validates :overdue_amount,   numericality: { greater_than_or_equal_to: 0 }

  def credit_available?
    available_credit > 0
  end

  def over_limit?
    current_balance > credit_limit
  end

  def overdue_bucket
    days = overdue_days.to_i
    OVERDUE_BUCKETS.find { |_, range| range.include?(days) }&.first || 'current'
  end

  # Sync available_credit and bucket whenever limit or balance changes
  before_save :recalculate_available_credit
  before_save :update_overdue_bucket_cache

  private

  def recalculate_available_credit
    self.available_credit = [credit_limit - current_balance, 0].max
  end

  def update_overdue_bucket_cache
    self.overdue_bucket_cached = overdue_bucket
  end
end
