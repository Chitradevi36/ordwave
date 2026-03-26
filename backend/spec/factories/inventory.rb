# frozen_string_literal: true

FactoryBot.define do
  factory :inventory_level do
    association :organization
    association :branch
    association :product
    qty_on_hand   { 0 }
    qty_reserved  { 0 }
    min_qty_threshold { nil }
  end

  factory :stock_movement do
    association :organization
    association :branch
    association :product
    association :created_by, factory: :user
    movement_type { 'purchase_posted' }
    direction     { 'in' }
    qty           { 10 }
    unit_cost     { 50.00 }
    occurred_at   { Time.current }
    metadata      { {} }
  end

  factory :inventory_reservation do
    association :organization
    association :branch
    association :product
    association :sales_order
    qty_reserved { 5 }
    status       { 'active' }
  end
end
