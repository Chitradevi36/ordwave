class CreditLimitChangeRequest < ApplicationRecord
  STATUSES = %w[pending approved rejected countered].freeze

  belongs_to :credit_account
  belongs_to :requested_by, class_name: 'User'
  belongs_to :decided_by,   class_name: 'User', optional: true

  validates :new_limit,  numericality: { greater_than: 0 }
  validates :reason,     presence: true
  validates :status,     inclusion: { in: STATUSES }

  validate :counter_offer_present_when_countered

  scope :pending,   -> { where(status: 'pending') }
  scope :decided,   -> { where(status: %w[approved rejected countered]) }
  scope :recent,    -> { order(created_at: :desc) }

  delegate :customer, to: :credit_account
  delegate :organization, to: :credit_account

  def pending?   = status == 'pending'
  def approved?  = status == 'approved'
  def rejected?  = status == 'rejected'
  def countered? = status == 'countered'

  private

  def counter_offer_present_when_countered
    if status == 'countered' && counter_offer_limit.blank?
      errors.add(:counter_offer_limit, "is required when countering")
    end
  end
end
