# frozen_string_literal: true

FactoryBot.define do
  factory :supplier do
    association :organization
    sequence(:name) { |n| "Supplier #{n}" }
    sequence(:code) { |n| "SUPP-#{n.to_s.rjust(3, '0')}" }
    status             { 'active' }
    phone              { '9876543210' }
    payment_terms_days { 30 }
  end

  factory :supplier_product do
    association :supplier
    association :product
    purchase_price { 100.00 }
    lead_time_days { 3 }
  end

  factory :purchase_invoice do
    association :organization
    association :branch
    association :supplier
    association :created_by, factory: :user
    sequence(:invoice_number) { |n| "INV-#{n.to_s.rjust(4, '0')}" }
    invoice_date { Date.current }
    due_date     { Date.current + 30 }
    status       { 'draft' }
    currency     { 'INR' }
    total_amount { 0 }
    tax_amount   { 0 }
    grand_total  { 0 }

    trait :posted do
      status    { 'posted' }
      posted_at { Time.current }
    end

    trait :cancelled do
      status       { 'cancelled' }
      cancelled_at { Time.current }
    end
  end

  factory :purchase_invoice_line do
    association :purchase_invoice
    association :product
    qty          { 5 }
    unit_price   { 100.00 }
    discount_pct { 0 }
    tax_rate     { 18 }
    tax_amount   { 90.00 }
    line_total   { 590.00 }
  end
end
