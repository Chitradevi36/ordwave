# PlanLimits — defines per-plan entitlements and enforces them at the service
# boundary.  All limit checks should go through this class so there is a single
# source of truth when limits are adjusted / a billing provider is integrated.
#
# Plans (mirrors User::PLANS / Organization::PLANS):
#   starter    — free / trial tier
#   growth     — mid-market paid
#   enterprise — custom / unlimited
#
# Usage:
#   limits = PlanLimits.for(current_organization)
#   limits.enforce_branch_limit!   # raises PlanLimitError if over cap
#   limits.enforce_user_limit!
#   limits.feature_enabled?(:exports)   # => true / false
#
class PlanLimits
  # ── Plan definitions ────────────────────────────────────────────────────────
  LIMITS = {
    "starter" => {
      max_branches:        1,
      max_active_users:    5,
      features: %w[].freeze
    },
    "growth" => {
      max_branches:        5,
      max_active_users:    25,
      features: %w[exports advanced_analytics].freeze
    },
    "enterprise" => {
      max_branches:        Float::INFINITY,
      max_active_users:    Float::INFINITY,
      features: %w[exports advanced_analytics webhooks custom_roles].freeze
    }
  }.freeze

  FEATURE_LABELS = {
    "exports"            => "Data exports",
    "advanced_analytics" => "Advanced analytics",
    "webhooks"           => "Webhooks",
    "custom_roles"       => "Custom roles"
  }.freeze

  class PlanLimitError < StandardError
    attr_reader :limit_type, :current, :max, :upgrade_to

    def initialize(message, limit_type:, current: nil, max: nil, upgrade_to: nil)
      super(message)
      @limit_type = limit_type
      @current    = current
      @max        = max
      @upgrade_to = upgrade_to
    end
  end

  # ── Factory ─────────────────────────────────────────────────────────────────
  def self.for(organization)
    new(organization)
  end

  def initialize(organization)
    @organization = organization
    @plan         = organization.plan.presence || "starter"
    @config       = LIMITS.fetch(@plan, LIMITS["starter"])
  end

  # ── Branch limit ─────────────────────────────────────────────────────────────
  def enforce_branch_limit!
    max     = @config[:max_branches]
    return if max == Float::INFINITY

    current = @organization.branches.not_deleted.count
    if current >= max
      raise PlanLimitError.new(
        "Your #{@plan.capitalize} plan allows up to #{max} branch#{'es' if max != 1}. " \
        "Please upgrade to add more branches.",
        limit_type:  :branches,
        current:     current,
        max:         max,
        upgrade_to:  next_plan
      )
    end
  end

  # ── User limit ───────────────────────────────────────────────────────────────
  def enforce_user_limit!
    max     = @config[:max_active_users]
    return if max == Float::INFINITY

    # Count distinct active members across all branches for this org
    current = @organization.memberships.active.select(:user_id).distinct.count
    if current >= max
      raise PlanLimitError.new(
        "Your #{@plan.capitalize} plan allows up to #{max} active user#{'s' if max != 1}. " \
        "Please upgrade to add more team members.",
        limit_type:  :users,
        current:     current,
        max:         max,
        upgrade_to:  next_plan
      )
    end
  end

  # ── Feature gate ─────────────────────────────────────────────────────────────
  def feature_enabled?(feature)
    @config[:features].include?(feature.to_s)
  end

  def enforce_feature!(feature)
    return if feature_enabled?(feature)

    label = FEATURE_LABELS.fetch(feature.to_s, feature.to_s.humanize)
    raise PlanLimitError.new(
      "#{label} is not available on the #{@plan.capitalize} plan. " \
      "Please upgrade to unlock this feature.",
      limit_type: :feature,
      upgrade_to: next_plan
    )
  end

  # ── Plan info (useful for frontend 'Your plan' UI) ──────────────────────────
  def summary
    max_b = @config[:max_branches]
    max_u = @config[:max_active_users]
    {
      plan:             @plan,
      max_branches:     max_b == Float::INFINITY ? nil : max_b,
      max_active_users: max_u == Float::INFINITY ? nil : max_u,
      features:         @config[:features]
    }
  end

  private

  def next_plan
    plans = User::PLANS  # ["starter", "growth", "enterprise"]
    idx   = plans.index(@plan)
    idx && idx < plans.length - 1 ? plans[idx + 1] : nil
  end
end
