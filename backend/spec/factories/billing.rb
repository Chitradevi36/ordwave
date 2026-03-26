# frozen_string_literal: true

FactoryBot.define do
  factory :subscription do
    association :organization
    plan     { "starter" }
    status   { "active" }
    quantity { 1 }
    current_period_start { Time.current.beginning_of_day }
    current_period_end   { 1.month.from_now.end_of_day }
    metadata { {} }

    trait :free do
      plan   { "free" }
      status { "active" }
    end

    trait :starter do
      plan { "starter" }
    end

    trait :pro do
      plan { "pro" }
    end

    trait :pending do
      status { "pending" }
      sequence(:razorpay_subscription_id) { |n| "sub_razorpay_pending_#{n}" }
    end

    trait :active do
      status { "active" }
      sequence(:razorpay_subscription_id) { |n| "sub_razorpay_active_#{n}" }
    end

    trait :past_due do
      status  { "past_due" }
      ends_at { 7.days.from_now }
      sequence(:razorpay_subscription_id) { |n| "sub_razorpay_pastdue_#{n}" }
    end

    trait :cancelled do
      status       { "cancelled" }
      cancelled_at { Time.current }
      ends_at      { 1.month.from_now }
      sequence(:razorpay_subscription_id) { |n| "sub_razorpay_cancelled_#{n}" }
    end

    trait :expired do
      status  { "expired" }
      ends_at { 1.day.ago }
    end
  end

  factory :billing_event do
    association :organization
    association :subscription
    event_type   { "subscription.charged" }
    payload      { {} }
    processed_at { Time.current }
    sequence(:razorpay_event_id) { |n| "evt_razorpay_#{n}" }

    trait :unprocessed do
      processed_at { nil }
    end

    trait :payment_failed do
      event_type { "payment.failed" }
    end

    trait :subscription_cancelled do
      event_type { "subscription.cancelled" }
    end

    trait :internal_free_plan do
      event_type         { "internal.free_plan_activated" }
      razorpay_event_id  { nil }
      subscription       { nil }
    end
  end

  factory :gstr1_export_record do
    association :organization
    association :generated_by, factory: :user
    sequence(:gstin) { |n| "27ABCDE#{n.to_s.rjust(4, '0')}A1Z5" }
    sequence(:return_period) { |n| format('%02d%04d', (n % 12) + 1, 2026) }
    period_from { Date.new(2026, 3, 1) }
    period_to   { Date.new(2026, 3, 31) }
    status      { 'ready' }
    b2b_count   { 0 }
    b2cl_count  { 0 }
    b2cs_count  { 0 }
    cdnr_count  { 0 }
    cdnur_count { 0 }
    total_invoice_count { 0 }
    total_cn_count      { 0 }
    error_count         { 0 }
    warning_count       { 0 }
  end
end
