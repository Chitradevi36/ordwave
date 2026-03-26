# frozen_string_literal: true

FactoryBot.define do
  factory :vehicle do
    association :organization
    sequence(:registration_number) { |n| "MH01AB#{n.to_s.rjust(4, '0')}" }
    vehicle_type   { 'truck' }
    capacity_kg    { 1000 }
    capacity_units { 500 }
    status         { 'active' }
  end

  factory :delivery_trip do
    association :organization
    association :branch
    association :vehicle
    sequence(:trip_number) { |n| "DT-0001-#{n.to_s.rjust(6, '0')}" }
    trip_date { Date.today }
    status    { 'draft' }
  end

  factory :trip_stop do
    association :delivery_trip
    association :sales_order
    sequence(:sequence) { |n| n }
    status { 'pending' }
  end

  factory :delivery_proof do
    association :trip_stop
    proof_type { 'photo' }
  end

  factory :return_record do
    association :trip_stop
    association :product
    qty_returned { 2 }
    condition    { 'good' }
    reason_code  { 'refused' }
  end
end
