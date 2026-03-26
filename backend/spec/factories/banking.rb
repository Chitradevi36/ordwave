# frozen_string_literal: true

FactoryBot.define do
  factory :bank_account do
    association :organization
    branch          { nil }
    bank_name       { "HDFC Bank" }
    account_name    { "Arya Rice Distributors" }
    account_number_masked { "••••4321" }
    ifsc            { "HDFC0001234" }
    status          { "active" }
  end

  factory :bank_statement_import do
    association :organization
    association :bank_account
    association :uploaded_by, factory: :user
    file_name   { "hdfc_march_2026.csv" }
    source_type { "csv" }
    status      { "uploaded" }
    rows_count              { 0 }
    processed_rows_count    { 0 }
    new_rows_count          { 0 }
    duplicate_rows_count    { 0 }
    failed_rows_count       { 0 }
  end

  factory :bank_transaction do
    association :organization
    association :bank_account
    txn_date         { Date.current }
    amount           { 1_180.0 }
    direction        { "credit" }
    narration        { "UPI/CR/RAJU STORES/UTR938383838" }
    normalized_narration { "UPI CR RAJU STORES UTR938383838" }
    status           { "unmatched" }
    raw_row_json     { {} }
    match_meta       { {} }
    sequence(:idempotency_key) { |n| Digest::SHA256.hexdigest("test-key-#{n}") }

    trait :credit do
      direction { "credit" }
    end

    trait :debit do
      direction { "debit" }
    end

    trait :suggested do
      status { "suggested" }
      match_score { 85.0 }
      match_rule  { "retailer_alias_and_amount" }
    end

    trait :auto_matched do
      status { "auto_matched" }
      match_score { 97.0 }
      match_rule  { "exact_invoice_number" }
    end

    trait :matched do
      status       { "matched" }
      match_score  { 100.0 }
      processed_at { Time.current }
    end

    trait :ignored do
      status       { "ignored" }
      processed_at { Time.current }
    end
  end

  factory :bank_transaction_match do
    association :bank_transaction
    score       { 90.0 }
    rule_code   { "exact_amount_single_open_invoice" }
    explanation { { strategy: "test" } }
    selected    { false }

    trait :selected do
      selected { true }
    end
  end
end
