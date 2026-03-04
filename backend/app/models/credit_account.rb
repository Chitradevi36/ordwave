class CreditAccount < ApplicationRecord
  belongs_to :customer
  belongs_to :organization
  belongs_to :branch

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

  # Sync available_credit whenever limit or balance changes
  before_save :recalculate_available_credit

  private

  def recalculate_available_credit
    self.available_credit = [credit_limit - current_balance, 0].max
  end
end
