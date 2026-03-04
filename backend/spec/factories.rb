FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { 'Password@123' }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    phone { '9876543210' }
    active { true }
  end

  factory :organization do
    sequence(:name) { |n| "Organization #{n}" }
    plan { 'starter' }
    active { true }
    city { 'Mumbai' }
    state { 'Maharashtra' }
  end

  factory :role do
    sequence(:name) { |n| Role::NAMES[n % Role::NAMES.size] }
    description { "#{name} role" }
  end

  factory :branch do
    association :organization
    sequence(:name) { |n| "Branch #{n}" }
    sequence(:code) { |n| "BR-#{n.to_s.rjust(3, '0')}" }
    city { 'Mumbai' }
    state { 'Maharashtra' }
    active { true }
  end

  factory :membership do
    association :user
    association :organization
    association :branch
    association :role
    active { true }
  end

  factory :pending_registration do
    sequence(:email) { |n| "pending#{n}@example.com" }
    current_step { 'initiate' }
    otp_code { '123456' }
    otp_sent_at { Time.current }
    expires_at { 24.hours.from_now }
    completed { false }
    data { {} }
  end

  factory :onboarding_progress do
    association :organization
    association :user
    completed { false }
  end
end
