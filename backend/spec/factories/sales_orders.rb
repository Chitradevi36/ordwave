# frozen_string_literal: true

FactoryBot.define do
  factory :sales_order do
    association :organization
    association :branch
    association :customer
    association :created_by, factory: :user
    sequence(:order_number) { |n| "SO-0001-#{n.to_s.rjust(6, '0')}" }
    status        { 'draft' }
    delivery_date { 7.days.from_now.to_date }
    notes         { 'Test order' }
    total_amount  { 0 }
    discount_amount { 0 }
  end

  factory :sales_order_line do
    association :sales_order
    association :product
    qty          { 10 }
    unit_price   { 100.00 }
    discount_pct { 0 }
    gst_rate     { 5 }
    price_source { 'standard' }
    line_total   { 1000.00 }
    hsn_code     { '10060010' }
    delivered_qty { 0 }
    returned_qty  { 0 }
  end
end
