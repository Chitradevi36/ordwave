# frozen_string_literal: true

FactoryBot.define do
  factory :pick_list do
    association :organization
    association :branch
    association :sales_order
    sequence(:pick_number) { |n| "PL-#{Date.today.strftime('%Y%m%d')}-#{n.to_s.rjust(4, '0')}" }
    status { 'pending' }
  end

  factory :pick_list_item do
    association :pick_list
    association :product
    qty_requested { 10 }
    qty_picked    { 0 }
  end
end
