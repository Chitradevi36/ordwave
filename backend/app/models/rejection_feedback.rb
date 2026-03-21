class RejectionFeedback < ApplicationRecord
  belongs_to :payment

  validates :confidence_score, :timestamp, presence: true
  validate :validate_timestamp_not_future

  scope :recent, -> { order(timestamp: :desc) }
  scope :for_date_range, ->(from_date, to_date) {
    where(timestamp: from_date.beginning_of_day..to_date.end_of_day)
  }
  scope :by_reason, ->(reason) { where(rejection_reason: reason) }

  # Statistics
  def self.false_positive_rate_by_confidence_band(from_date, to_date)
    bands = {}
    
    for_date_range(from_date, to_date).each do |feedback|
      band = confidence_band(feedback.confidence_score)
      bands[band] ||= { count: 0, reasons: Hash.new(0) }
      bands[band][:count] += 1
      bands[band][:reasons][feedback.rejection_reason] += 1
    end
    
    bands
  end

  def self.confidence_band(score)
    case score
    when 0..50
      '0-50%'
    when 50..70
      '50-70%'
    when 70..85
      '70-85%'
    when 85..95
      '85-95%'
    else
      '95-100%'
    end
  end

  private

  def validate_timestamp_not_future
    if timestamp.present? && timestamp > Time.current
      errors.add(:timestamp, "cannot be in the future")
    end
  end
end
