# frozen_string_literal: true

FactoryBot.define do
  factory :route do
    association :organization
    association :branch
    sequence(:name) { |n| "Route #{n}" }
    sequence(:code) { |n| "RT-#{n.to_s.rjust(3, '0')}" }
    active { true }
  end

  factory :customer do
    association :organization
    association :branch
    association :route
    sequence(:name) { |n| "Customer #{n}" }
    sequence(:code) { |n| "CUST-#{n.to_s.rjust(4, '0')}" }
    channel  { 'general_trade' }
    tier     { 'bronze' }
    status   { 'active' }
    phone    { Faker::PhoneNumber.cell_phone }
    email    { Faker::Internet.email }
    credit_limit { 50_000.00 }
  end

  factory :customer_address do
    association :customer
    label       { 'billing' }
    line1       { Faker::Address.street_address }
    city        { Faker::Address.city }
    state       { Faker::Address.state }
    postal_code { Faker::Address.zip_code }
    country     { 'India' }
  end

  factory :customer_contact do
    association :customer
    name       { Faker::Name.name }
    phone      { Faker::PhoneNumber.cell_phone }
    email      { Faker::Internet.email }
    designation { 'Owner' }
    is_primary { false }
  end
end
