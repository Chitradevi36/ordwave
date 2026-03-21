class PaymentSuggestion < ApplicationRecord
  belongs_to :bank_transaction
  belongs_to :invoice
  belongs_to :approved_by, class_name: 'User', optional: true

  enum status: {
    pending_approval: 'pending_approval',
    approved: 'approved',
    rejected: 'rejected'
  }

  validates :confidence_score, presence: true
  validates :status, presence: true, inclusion: { in: statuses.keys }

  scope :pending, -> { where(status: 'pending_approval') }
  scope :approved, -> { where(status: 'approved') }
  scope :rejected, -> { where(status: 'rejected') }
  scope :recent, -> { order(created_at: :desc) }
  scope :for_date_range, ->(from_date, to_date) {
    where(created_at: from_date.beginning_of_day..to_date.end_of_day)
  }

  def approve!(user)
    update!(
      status: 'approved',
      approved_by: user,
      approved_at: Time.current
    )
  end

  def reject!
    update!(status: 'rejected')
  end

  def pending?
    status == 'pending_approval'
  end

  def approved?
    status == 'approved'
  end

  def rejected?
    status == 'rejected'
  end

  def high_confidence?
    confidence_score >= 95
  end

  def medium_confidence?
    confidence_score >= 85 && confidence_score < 95
  end

  def low_confidence?
    confidence_score < 85
  end
end
