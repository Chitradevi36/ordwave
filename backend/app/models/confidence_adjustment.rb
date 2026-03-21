class ConfidenceAdjustment < ApplicationRecord
  validates :model_version, presence: true, uniqueness: true
  
  # Default values for all thresholds
  def self.defaults
    {
      amount_tolerance_pct: 2.0,
      date_tolerance_days: 3,
      customer_fuzzy_minimum: 0.80,
      reference_weight: 15,
      auto_post_threshold: 95,
      suggestion_threshold: 85,
      rejection_window_minutes: 60
    }
  end

  scope :active, -> { order(model_version: :desc).limit(1) }
  scope :latest, -> { order(model_version: :desc).first }

  def to_configuration_hash
    {
      'amount_tolerance_pct' => amount_tolerance_pct,
      'date_tolerance_days' => date_tolerance_days,
      'customer_fuzzy_minimum' => customer_fuzzy_minimum,
      'reference_weight' => reference_weight,
      'auto_post_threshold' => auto_post_threshold,
      'suggestion_threshold' => suggestion_threshold,
      'rejection_window_minutes' => rejection_window_minutes
    }
  end

  def self.create_or_update_configuration(params = {})
    defaults.merge(params).tap do |config|
      next_version = (latest&.model_version || 0) + 1
      create!(
        model_version: next_version,
        **config
      )
    end
  end
end
