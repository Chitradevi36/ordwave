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

  factory :invitation do
    association :organization
    association :role
    association :branch
    sequence(:email) { |n| "invite#{n}@example.com" }
    token_digest     { Invitation.digest(Invitation.generate_token) }
    invited_by       { create(:user) }
    status           { 'pending' }
    expires_at       { 72.hours.from_now }
  end

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
  end
end
