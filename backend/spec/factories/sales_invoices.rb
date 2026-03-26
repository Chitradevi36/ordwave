# frozen_string_literal: true

FactoryBot.define do
  factory :sales_invoice do
    association :organization
    association :branch
    association :customer
    association :created_by, factory: :user
    sequence(:invoice_number) { |n| "SI-TEST-#{Time.current.strftime('%Y%m')}-#{n.to_s.rjust(4, '0')}" }
    invoice_date      { Date.today }
    status            { 'issued' }
    subtotal          { 1_000.0 }
    tax_total         {   180.0 }
    grand_total       { 1_180.0 }
    currency          { 'INR' }
    generation_source { 'manual_direct' }
    issued_at         { Time.current }
  end

  factory :sales_invoice_line do
    association :sales_invoice
    association :product
    qty           { 10 }
    unit_price    { 100.0 }
    discount_pct  {   0.0 }
    taxable_value { 1_000.0 }
    hsn_code      { '10060010' }
    gst_rate      { 18.0 }
    cgst_rate     {  9.0 }
    sgst_rate     {  9.0 }
    igst_rate     {  0.0 }
    cgst_amount   { 90.0 }
    sgst_amount   { 90.0 }
    igst_amount   {  0.0 }
    tax_amount    { 180.0 }
    line_total    { 1_180.0 }
  end

  factory :payment do
    association :organization
    association :branch
    association :customer
    association :created_by, factory: :user
    sequence(:payment_number) { |n| "PAY-TEST-#{Time.current.strftime('%Y%m')}-#{n.to_s.rjust(4, '0')}" }
    amount            { 1_000.0 }
    payment_mode      { 'cash' }
    received_date     { Date.today }
    status            { 'draft' }
    allocated_amount  { 0.0 }
    unallocated_amount { 0.0 }
  end

  factory :payment_allocation do
    association :payment
    association :sales_invoice
    allocated_amount { 500.0 }
    status           { 'active' }
  end

  factory :advance_payment do
    association :organization
    association :branch
    association :customer
    association :source_payment, factory: :payment
    original_amount { 500.0 }
    balance         { 500.0 }
    status          { 'unapplied' }
  end

  # Aliases for convenience
  factory :invoice, parent: :sales_invoice do
  end
end
