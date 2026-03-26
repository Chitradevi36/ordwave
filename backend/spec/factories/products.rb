# frozen_string_literal: true

FactoryBot.define do
  factory :hsn_sac_code do
    sequence(:code) { |n| "1006#{n.to_s.rjust(4, '0')}" }
    code_type      { 'HSN' }
    description    { Faker::Commerce.product_name }
    chapter        { '10' }
    gst_rate       { 5 }
    active         { true }
    effective_from { Date.new(2017, 7, 1) }
    effective_to   { nil }
  end

  factory :product_category do
    association :organization
    sequence(:name) { |n| "Category #{n}" }
  end

  factory :unit_of_measure do
    sequence(:name)   { |n| "Unit #{n}" }
    sequence(:symbol) { |n| "U#{n}" }
    active { true }
  end

  factory :product do
    association :organization
    association :product_category
    association :unit_of_measure
    association :hsn_sac_code
    sequence(:sku)  { |n| "PROD-#{n.to_s.rjust(4, '0')}" }
    name            { Faker::Commerce.product_name }
    gst_rate        { 5 }
    min_order_qty   { 1 }
    status          { 'active' }
  end

  factory :price_list do
    association :organization
    association :branch
    sequence(:name) { |n| "Price List #{n}" }
    list_type  { 'standard' }
    valid_from { Date.today }
    valid_to   { nil }
  end

  factory :price_list_item do
    association :price_list
    association :product
    unit_price   { Faker::Commerce.price(range: 10..500) }
    min_qty      { 1 }
    discount_pct { 0 }
  end

  factory :retailer_price_list_assignment do
    association :customer
    association :price_list
    starts_on { Date.today }
    ends_on   { nil }
    active    { true }
  end

  factory :tier_price_list_assignment do
    association :branch
    association :price_list
    retailer_tier { 'bronze' }
    starts_on     { Date.today }
    ends_on       { nil }
    active        { true }
  end
end
