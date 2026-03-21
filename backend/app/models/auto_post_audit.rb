class AutoPostAudit < ApplicationRecord
  belongs_to :payment, optional: true
  belongs_to :bank_transaction, optional: true
  belongs_to :actor, class_name: 'User', optional: true

  enum action: {
    auto_posted: 'auto_posted',
    rejected_by_finance: 'rejected_by_finance',
    rejected_by_window: 'rejected_by_window'
  }

  validates :action, :timestamp, presence: true
  validate :validate_timestamp_not_future

  scope :auto_posted, -> { where(action: 'auto_posted') }
  scope :rejected, -> { where(action: ['rejected_by_finance', 'rejected_by_window']) }
  scope :recent, -> { order(timestamp: :desc) }
  scope :for_date_range, ->(from_date, to_date) {
    where(timestamp: from_date.beginning_of_day..to_date.end_of_day)
  }

  def auto_posted?
    action == 'auto_posted'
  end

  def rejected?
    action.start_with?('rejected')
  end

  private

  def validate_timestamp_not_future
    if timestamp.present? && timestamp > Time.current
      errors.add(:timestamp, "cannot be in the future")
    end
  end
end
