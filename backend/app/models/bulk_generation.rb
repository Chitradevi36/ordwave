# frozen_string_literal: true

class BulkGeneration < ApplicationRecord
  belongs_to :organization
  belongs_to :user

  enum status: { in_progress: 'in_progress', completed: 'completed', failed: 'failed' }

  validates :organization_id, presence: true
  validates :user_id, presence: true
  validates :session_id, presence: true, uniqueness: true
  validates :total_count, numericality: { only_integer: true, greater_than: 0 }
  validates :completed_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :error_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :recent, -> { order(created_at: :desc) }
  scope :active, -> { where(completed_at: nil) }
  scope :completed, -> { where.not(completed_at: nil) }

  # Percentage of invoices generated successfully
  def success_rate
    return 0 if total_count.zero?
    (((total_count - error_count).to_f / total_count) * 100).round(1)
  end

  def success_count
    total_count - error_count
  end

  def progress_percent
    return 0 if total_count.zero?
    ((completed_count.to_f / total_count) * 100).round(0)
  end

  def duration_minutes
    return nil if completed_at.blank?
    ((completed_at - created_at) / 60).round(2)
  end

  def self.cleanup_old_records(days: 7)
    where('created_at < ?', days.days.ago).delete_all
  end
end
