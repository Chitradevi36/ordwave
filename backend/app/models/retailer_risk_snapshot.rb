# frozen_string_literal: true
#
# Stores a point-in-time risk assessment for a retailer.
# A new snapshot is generated whenever #recompute! is called.
# The "current" snapshot is the most recently computed one.
#
class RetailerRiskSnapshot < ApplicationRecord
  TIERS         = %w[low medium high critical].freeze
  SCORE_VERSION = 'v1'.freeze

  belongs_to :organization
  belongs_to :customer

  validates :risk_score,     numericality: { in: 0..100 }, presence: true
  validates :risk_tier,      inclusion: { in: TIERS }
  validates :recommendation, presence: true
  validates :computed_at,    presence: true
  validates :score_version,  presence: true

  scope :latest_for,    ->(customer) { where(customer: customer).order(computed_at: :desc).first }
  scope :for_org,       ->(org)      { where(organization: org) }
  scope :current,       ->           { where("computed_at > ?", 24.hours.ago) }
  scope :by_tier,       ->(tier)     { where(risk_tier: tier) }
  scope :riskiest,      ->(n = 10)   { order(risk_score: :desc).limit(n) }

  # ── Tier helpers ─────────────────────────────────────────────────────────
  TIERS.each { |t| define_method(:"#{t}?") { risk_tier == t } }

  def stale?
    computed_at < 6.hours.ago
  end

  # Returns factors as a list of hashes with :label, :points, :detail keys
  def factor_list
    (factors_json['factors'] || []).map(&:symbolize_keys)
  end

  def tier_color
    { 'low' => 'success', 'medium' => 'warning', 'high' => 'danger', 'critical' => 'danger' }[risk_tier] || 'secondary'
  end
end
