# frozen_string_literal: true

FactoryBot.define do
  factory :return_request do
    association :organization
    association :branch
    association :customer
    association :created_by, factory: :user
    source_type   { 'manual' }
    return_date   { Date.current }
    status        { 'draft' }
    return_number { nil }
  end

  factory :return_line do
    association :return_request
    association :product
    qty_reported        { 5 }
    condition_reported  { 'unknown' }
    reason_code         { 'other' }
    unit_price_snapshot { nil }
    gst_rate_snapshot   { nil }
    hsn_code_snapshot   { nil }
  end

  factory :return_qc_item do
    association :return_line
    association :qc_by, factory: :user
    qty_resalable   { 3 }
    qty_damaged     { 1 }
    qty_expired     { 0 }
    condition_final { 'mixed' }
    qc_at           { Time.current }
  end

  factory :credit_note do
    association :organization
    association :branch
    association :customer
    association :return_request
    association :created_by, factory: :user
    credit_note_number { nil }
    status   { 'draft' }
    subtotal  { 0 }
    tax_total { 0 }
    total     { 0 }
  end

  factory :credit_note_line do
    association :credit_note
    association :product
    qty        { 3 }
    unit_price { 100.0 }
    gst_rate   { 18.0 }
  end
end
