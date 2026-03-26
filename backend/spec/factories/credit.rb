# frozen_string_literal: true

FactoryBot.define do
  factory :credit_account do
    association :customer
    association :organization
    association :branch
    credit_limit     { 50_000.00 }
    current_balance  { 0 }
    available_credit { 50_000.00 }
    overdue_amount   { 0 }
    overdue_days     { 0 }
    collection_first { false }
    hold_required    { false }
    watchlist        { false }
  end

  factory :credit_policy do
    association :organization
    hard_block_overdue_days    { 30 }
    hard_block_margin_pct      { 20.0 }
    soft_hold_overdue_days_min { 15 }
    soft_hold_overdue_days_max { 29 }
    soft_hold_outstanding_pct  { 100.0 }
    collection_first_bucket    { 'serious' }
    approval_sla_hours_manager { 4 }
    approval_sla_hours_owner   { 8 }
    auto_invoice_trigger       { 'on_delivery' }
    allow_partial_allocation   { true }
  end

  factory :prepayment_sku do
    association :organization
    association :product
    association :created_by, factory: :user
    reason         { 'High risk product' }
    effective_from { Date.current }
    active         { true }
  end

  factory :credit_limit_change_request do
    association :credit_account
    association :requested_by, factory: :user
    new_limit { 100_000.00 }
    reason    { 'Expanding business, needs higher limit.' }
    status    { 'pending' }
  end

  factory :audit_log do
    association :organization
    association :actor, factory: :user
    association :auditable, factory: :credit_account
    action      { 'credit_limit_changed' }
    changes_data { { from: 50_000, to: 100_000 } }
  end

  factory :retailer_risk_snapshot do
    association :organization
    association :customer
    risk_score     { 20 }
    risk_tier      { 'low' }
    recommendation { 'Allow order — retailer is in good standing.' }
    factors_json   { { factors: [] } }
    score_version  { 'v1' }
    computed_at    { Time.current }

    trait :medium do
      risk_score { 35 }
      risk_tier  { 'medium' }
      recommendation { 'Allow order with warning — review outstanding balance.' }
    end

    trait :high do
      risk_score { 60 }
      risk_tier  { 'high' }
      recommendation { 'Hold order — manager approval required before dispatch.' }
    end

    trait :critical do
      risk_score { 80 }
      risk_tier  { 'critical' }
      recommendation { 'Block order — require full collection before new order.' }
    end

    trait :stale do
      computed_at { 8.hours.ago }
    end
  end
end
