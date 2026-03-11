# frozen_string_literal: true

# Additional factories for GST engine domain models.
# Append this to spec/factories.rb or require from spec_helper.rb.
# These are standalone factory definitions that follow the existing factory pattern.

FactoryBot.define do
  factory :financial_year do
    association :organization
    sequence(:code) { |n| "FY#{2024 + n}-#{(2025 + n).to_s.last(2)}" }
    sequence(:label) { |n| "Apr #{2024 + n} – Mar #{2025 + n}" }
    start_date { Date.new(2025, 4, 1) }
    end_date   { Date.new(2026, 3, 31) }
    starts_on_month { 4 }
    starts_on_day   { 1 }
    status { 'open' }

    trait :locked do
      status { 'locked' }
      books_locked_at { 1.week.ago }
    end

    trait :gst_locked do
      gst_locked_at { 1.week.ago }
    end

    trait :closed do
      status { 'closed' }
      closed_at { 1.day.ago }
    end
  end

  factory :gst_return_period do
    association :organization
    association :financial_year
    month { 9 }
    year  { 2025 }
    return_type     { 'gstr1' }
    status          { 'draft' }
    period_start_on { Date.new(2025, 9, 1) }
    period_end_on   { Date.new(2025, 9, 30) }
    financial_year_label { 'FY2025-26' }

    trait :generated do
      status { 'generated' }
      generated_at { 1.hour.ago }
    end

    trait :locked do
      status { 'locked' }
      locked_at { 30.minutes.ago }
    end

    trait :filed do
      status { 'filed' }
      filed_at { 15.minutes.ago }
    end

    trait :gstr3b do
      return_type { 'gstr3b' }
    end

    trait :gstr2b_import do
      return_type { 'gstr2b_import' }
    end
  end

  factory :gst_return_snapshot do
    association :gst_return_period
    association :organization
    section_key    { 'full' }
    payload        { { 'b2b' => [], 'summary' => {} } }
    totals         { { 'taxable_value' => 100_000.0, 'tax_value' => 18_000.0 } }
    source_counts  { { 'invoices' => 5 } }
    source_invoice_ids { { 'b2b' => [1, 2, 3] } }
    generated_at   { Time.current }
    version_number { 1 }
    source_hash    { SecureRandom.hex(32) }
    snapshot_hash  { SecureRandom.hex(32) }
    is_filed       { false }

    trait :filed do
      is_filed { true }
    end
  end

  factory :gst2b_import do
    association :organization
    gstin          { '27AAPFU0939F1ZV' }
    month          { 9 }
    year           { 2025 }
    period_start_on { Date.new(2025, 9, 1) }
    period_end_on   { Date.new(2025, 9, 30) }
    import_status  { 'completed' }
    source_type    { 'json' }
    total_rows     { 10 }
    matched_rows   { 8 }
    unmatched_rows { 2 }
    error_rows     { 0 }
    imported_at    { 1.hour.ago }

    trait :uploaded do
      import_status { 'uploaded' }
      total_rows    { 0 }
      matched_rows  { 0 }
    end

    trait :failed do
      import_status { 'failed' }
      error_message { 'Parse error: unexpected token' }
    end
  end

  factory :gst2b_import_line do
    association :gst2b_import
    association :organization
    supplier_gstin  { '27AAPFU0939F1ZV' }
    supplier_name   { 'Test Supplier Pvt Ltd' }
    sequence(:invoice_number) { |n| "INV-2025-#{n.to_s.rjust(4, '0')}" }
    invoice_date    { Date.new(2025, 9, 15) }
    invoice_value   { 118_000.0 }
    taxable_value   { 100_000.0 }
    igst            { 18_000.0 }
    cgst            { 0.0 }
    sgst            { 0.0 }
    document_type   { 'invoice' }
    section_type    { 'b2b' }
    match_status    { 'pending' }
    itc_available   { true }
    reverse_charge  { false }

    trait :matched do
      match_status    { 'matched' }
      match_confidence { 1.0 }
      match_explanation { 'Tier-1 exact match (ok)' }
    end

    trait :missing_in_books do
      match_status { 'missing_in_books' }
    end

    trait :tax_mismatch do
      match_status    { 'tax_mismatch' }
      match_confidence { 0.75 }
    end
  end

  factory :gst_reconciliation_issue do
    association :organization
    issue_type  { 'missing_in_books' }
    severity    { 'high' }
    status      { 'open' }
    supplier_gstin { '27AAPFU0939F1ZV' }
    sequence(:invoice_number) { |n| "INV-#{n}" }
    invoice_date   { Date.new(2025, 9, 15) }
    amount_portal  { 18_000.0 }

    trait :tax_mismatch do
      issue_type        { 'tax_mismatch' }
      amount_books      { 17_500.0 }
      amount_portal     { 18_000.0 }
      difference_amount { 500.0 }
    end

    trait :resolved do
      status      { 'resolved' }
      resolved_at { 1.hour.ago }
    end

    trait :blocking do
      severity { 'blocking' }
    end
  end
end
