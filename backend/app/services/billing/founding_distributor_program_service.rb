module Billing
  class FoundingDistributorProgramService
    Result = Struct.new(
      :success?,
      :eligible,
      :claimed,
      :capacity,
      :remaining_spots,
      :founding_subscription,
      :errors,
      keyword_init: true
    )

    CAPACITY = 10
    FOUNDING_PRICE_PAISE = 49_900
    STANDARD_GROWTH_PRICE_PAISE = 99_900
    PRICE_LOCK_MONTHS = 12

    def initialize(organization:, now: Time.current)
      @organization = organization
      @now = now
    end

    def eligible?
      remaining_spots.positive?
    end

    def remaining_spots
      [CAPACITY - claimed_count, 0].max
    end

    def claimed_count
      Subscription.where(plan: "growth")
                  .where("metadata ->> 'pricing_variant' = ?", "founding")
                  .where(status: %w[pending active past_due cancelled expired])
                  .count
    end

    def call
      if founding_subscription.present?
        return Result.new(
          success?: true,
          eligible: true,
          claimed: true,
          capacity: CAPACITY,
          remaining_spots: remaining_spots,
          founding_subscription: founding_subscription,
          errors: []
        )
      end

      return Result.new(
        success?: false,
        eligible: false,
        claimed: false,
        capacity: CAPACITY,
        remaining_spots: remaining_spots,
        founding_subscription: nil,
        errors: ["Founding program is full"]
      ) unless eligible?

      subscription = nil
      Subscription.transaction do
        lock_scope = Subscription.where(plan: "growth")
                                 .where("metadata ->> 'pricing_variant' = ?", "founding")
                                 .lock
        current_count = lock_scope.count
        raise ActiveRecord::Rollback if current_count >= CAPACITY

        subscription = @organization.subscriptions.create!(
          plan: "growth",
          status: "pending",
          metadata: {
            "pricing_variant" => "founding",
            "founding_start_date" => @now.iso8601,
            "founding_end_date" => (@now + PRICE_LOCK_MONTHS.months).iso8601,
            "founding_price_paise" => FOUNDING_PRICE_PAISE,
            "standard_growth_price_paise" => STANDARD_GROWTH_PRICE_PAISE
          }
        )
      end

      if subscription.present?
        Result.new(
          success?: true,
          eligible: true,
          claimed: true,
          capacity: CAPACITY,
          remaining_spots: remaining_spots - 1,
          founding_subscription: subscription,
          errors: []
        )
      else
        Result.new(
          success?: false,
          eligible: false,
          claimed: false,
          capacity: CAPACITY,
          remaining_spots: remaining_spots,
          founding_subscription: nil,
          errors: ["Founding program is full"]
        )
      end
    end
  end
end
