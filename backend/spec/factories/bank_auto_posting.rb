FactoryBot.define do
  factory :auto_post_audit do
    payment { association(:payment, auto_posted: true) }
    bank_transaction { association(:bank_transaction) }
    confidence_breakdown do
      {
        amount: { score: 30, value: "Exact match" },
        date: { score: 20, value: "Same day" },
        customer: { score: 25, value: "Exact match" },
        reference: { score: 15, value: "Invoice number found" }
      }
    end
    auto_posted { true }
    action { 'auto_posted' }
    actor { nil }  # System auto-post
    timestamp { Time.current }
    audit_notes { "Auto-posted at 90% confidence" }

    trait :auto_posted_action do
      action { 'auto_posted' }
      auto_posted { true }
    end

    trait :rejected_by_finance do
      action { 'rejected_by_finance' }
      auto_posted { false }
      actor { association(:user) }
      audit_notes { "Rejected by finance: Customer name mismatch" }
    end

    trait :rejected_by_window do
      action { 'rejected_by_window' }
      auto_posted { false }
      audit_notes { "Rejection window timeout" }
    end
  end

  factory :rejection_feedback do
    payment { association(:payment, auto_posted: true) }
    confidence_score { rand(95.0..100.0).round(2) }
    rejection_reason { "Customer name mismatch" }
    timestamp { Time.current }

    trait :by_customer_mismatch do
      rejection_reason { "Customer name mismatch" }
    end

    trait :by_amount_mismatch do
      rejection_reason { "Amount doesn't match" }
      confidence_score { rand(85.0..95.0).round(2) }
    end

    trait :by_date_mismatch do
      rejection_reason { "Date too old" }
    end

    trait :by_reference_mismatch do
      rejection_reason { "No matching invoice reference" }
    end
  end

  factory :confidence_adjustment do
    amount_tolerance_pct { 2.0 }
    date_tolerance_days { 3 }
    customer_fuzzy_minimum { 0.80 }
    reference_weight { 15 }
    auto_post_threshold { 95 }
    suggestion_threshold { 85 }
    rejection_window_minutes { 60 }
    model_version { 1 }

    trait :strict_thresholds do
      amount_tolerance_pct { 1.0 }
      date_tolerance_days { 1 }
      customer_fuzzy_minimum { 0.95 }
      auto_post_threshold { 98 }
    end

    trait :lenient_thresholds do
      amount_tolerance_pct { 5.0 }
      date_tolerance_days { 5 }
      customer_fuzzy_minimum { 0.70 }
      auto_post_threshold { 90 }
    end

    trait :short_rejection_window do
      rejection_window_minutes { 15 }
    end

    trait :long_rejection_window do
      rejection_window_minutes { 120 }
    end
  end

  factory :payment_suggestion do
    bank_transaction { association(:bank_transaction) }
    invoice { association(:invoice) }
    confidence_score { rand(85.0..94.99).round(2) }
    confidence_breakdown do
      {
        amount: { score: 25, value: "±1% diff" },
        date: { score: 18, value: "±1 day" },
        customer: { score: 20, value: "90% match" },
        reference: { score: 15, value: "Invoice number found" }
      }
    end
    status { 'pending_approval' }
    approved_by { nil }
    approved_at { nil }

    trait :pending do
      status { 'pending_approval' }
    end

    trait :approved do
      status { 'approved' }
      approved_by { association(:user) }
      approved_at { Time.current }
    end

    trait :rejected do
      status { 'rejected' }
    end

    trait :high_confidence do
      confidence_score { 93.5 }
    end

    trait :medium_confidence do
      confidence_score { 88.75 }
    end

    trait :low_confidence do
      confidence_score { 85.0 }
    end
  end
end
