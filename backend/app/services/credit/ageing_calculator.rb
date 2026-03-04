module Credit
  class AgeingCalculator
    BUCKETS = {
      bucket_0_30:  (0..30),
      bucket_31_60: (31..60),
      bucket_61_90: (61..90),
      bucket_90_plus: (91..Float::INFINITY)
    }.freeze

    def initialize(customer:)
      @customer = customer
    end

    # Returns a hash with outstanding amounts grouped by ageing bucket.
    # Extend with real invoice lookup once an Invoices model exists.
    def call
      overdue_days = credit_account&.overdue_days.to_i
      overdue_amount = credit_account&.overdue_amount.to_d

      bucket = classify_bucket(overdue_days)

      {
        bucket_0_30:   bucket == :bucket_0_30   ? overdue_amount : 0,
        bucket_31_60:  bucket == :bucket_31_60  ? overdue_amount : 0,
        bucket_61_90:  bucket == :bucket_61_90  ? overdue_amount : 0,
        bucket_90_plus: bucket == :bucket_90_plus ? overdue_amount : 0,
        total_overdue: overdue_amount,
        overdue_days:  overdue_days
      }
    end

    private

    def credit_account
      @credit_account ||= @customer.credit_account
    end

    def classify_bucket(days)
      BUCKETS.find { |_key, range| range.include?(days) }&.first || :bucket_0_30
    end
  end
end
