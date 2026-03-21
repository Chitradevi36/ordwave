module Payments
  class ConfidenceScorerService
    include ServiceResult

    # Inputs:
    # - bank_transaction: BankTransaction
    # - matching_invoice: Invoice  
    # - configuration: Hash (optional, uses default if nil)
    #
    # Output: Result { success?, confidence_score (0-100), breakdown: Hash }

    def initialize(bank_transaction:, matching_invoice:, configuration: nil)
      @bank_transaction = bank_transaction
      @matching_invoice = matching_invoice
      @configuration = configuration || load_default_configuration
    end

    def call
      validate_inputs
      calculate_confidence
    end

    private

    def validate_inputs
      return failure("Bank transaction not found") unless @bank_transaction.present?
      return failure("Matching invoice not found") unless @matching_invoice.present?
      success
    end

    def calculate_confidence
      amount_score = score_amount_match
      date_score = score_date_match
      customer_score = score_customer_match
      reference_score = score_reference_match
      history_score = score_historical_accuracy

      # Total: 0-100
      total_before_ml = amount_score + date_score + customer_score + reference_score + history_score
      confidence = [total_before_ml.round(2), 100].min  # Cap at 100

      # Apply ML adjustment (placeholder for future enhancement)
      confidence = apply_ml_adjustment(confidence, {
        amount: amount_score,
        date: date_score,
        customer: customer_score,
        reference: reference_score,
        history: history_score
      })

      breakdown_hash = {
        amount: {
          score: amount_score,
          value: amount_description,
          tolerance: @configuration['amount_tolerance_pct']
        },
        date: {
          score: date_score,
          value: date_description,
          tolerance: @configuration['date_tolerance_days']
        },
        customer: {
          score: customer_score,
          value: customer_description,
          threshold: @configuration['customer_fuzzy_minimum']
        },
        reference: {
          score: reference_score,
          value: reference_description,
          weight: @configuration['reference_weight']
        },
        history: {
          score: history_score,
          value: "Historical accuracy adjustment"
        }
      }

      log_confidence_breakdown(confidence, breakdown_hash)

      success({
        confidence: confidence,
        breakdown: breakdown_hash
      })
    rescue => e
      failure("Error calculating confidence: #{e.message}")
    end

    def score_amount_match
      return 0 if @bank_transaction.amount.blank? || @matching_invoice.total.blank?

      amount_diff = (@bank_transaction.amount - @matching_invoice.total).abs
      tolerance_pct = (amount_diff / @matching_invoice.total.to_f) * 100
      tolerance_threshold = @configuration['amount_tolerance_pct']

      if tolerance_pct == 0
        30
      elsif tolerance_pct <= tolerance_threshold
        25
      elsif tolerance_pct <= (tolerance_threshold * 2.5)  # ±5% tolerance
        15
      else
        0
      end
    rescue
      0
    end

    def score_date_match
      return 0 if @bank_transaction.date.blank? || @matching_invoice.issue_date.blank?

      date_diff = (@bank_transaction.date - @matching_invoice.issue_date.to_date).abs
      tolerance_days = @configuration['date_tolerance_days']

      if date_diff == 0
        20
      elsif date_diff <= 1
        18
      elsif date_diff <= tolerance_days
        15
      else
        0
      end
    rescue
      0
    end

    def score_customer_match
      return 0 if @bank_transaction.customer_name.blank? || @matching_invoice.customer.blank?

      similarity = fuzzy_match_score(
        @bank_transaction.customer_name,
        @matching_invoice.customer.name
      )

      minimum_threshold = @configuration['customer_fuzzy_minimum']

      if similarity >= 1.0
        25
      elsif similarity >= 0.90
        20
      elsif similarity >= minimum_threshold
        10
      else
        0
      end
    rescue
      0
    end

    def score_reference_match
      return 0 if @bank_transaction.reference.blank?

      references = [
        @matching_invoice.invoice_number,
        @matching_invoice.order&.order_number
      ].compact

      match_found = references.any? { |ref| @bank_transaction.reference.to_s.upcase.include?(ref.to_s.upcase) }

      match_found ? @configuration['reference_weight'].to_i : 0
    rescue
      0
    end

    def score_historical_accuracy
      # Placeholder for ML component
      # Future: Track successful matches vs rejections and adjust
      # For MVP: Fixed at 0, but structure supports future ML integration
      0
    end

    def apply_ml_adjustment(base_confidence, breakdown)
      # Placeholder for ML integration
      # Will read learned thresholds from database in Phase 3.2
      base_confidence
    end

    def fuzzy_match_score(str1, str2)
      return 0.0 if str1.blank? || str2.blank?

      str1_upcase = str1.to_s.upcase.gsub(/[^A-Z0-9]/, '')
      str2_upcase = str2.to_s.upcase.gsub(/[^A-Z0-9]/, '')

      return 1.0 if str1_upcase == str2_upcase

      # Levenshtein distance based similarity
      distance = levenshtein_distance(str1_upcase, str2_upcase)
      max_length = [str1_upcase.length, str2_upcase.length].max

      return 0.0 if max_length == 0

      1.0 - (distance.to_f / max_length)
    end

    def levenshtein_distance(s1, s2)
      if s1.length == 0
        return s2.length
      end

      if s2.length == 0
        return s1.length
      end

      d = Array.new(s1.length + 1) { Array.new(s2.length + 1) }

      (0..s1.length).each { |i| d[i][0] = i }
      (0..s2.length).each { |j| d[0][j] = j }

      (1..s1.length).each do |i|
        (1..s2.length).each do |j|
          cost = s1[i - 1] == s2[j - 1] ? 0 : 1

          d[i][j] = [
            d[i - 1][j] + 1,      # deletion
            d[i][j - 1] + 1,      # insertion
            d[i - 1][j - 1] + cost # substitution
          ].min
        end
      end

      d[s1.length][s2.length]
    end

    def log_confidence_breakdown(confidence, breakdown)
      # Audit logging for compliance/debugging
      # Can be integrated with Credit::AuditLogger if available
      Rails.logger.info("ConfidenceScore: #{confidence}% | Breakdown: #{breakdown.inspect}")
    end

    def load_default_configuration
      config = ConfidenceAdjustment.latest
      config&.attributes&.symbolize_keys || {
        'amount_tolerance_pct' => 2.0,
        'date_tolerance_days' => 3,
        'customer_fuzzy_minimum' => 0.80,
        'reference_weight' => 15,
        'auto_post_threshold' => 95,
        'suggestion_threshold' => 85,
        'rejection_window_minutes' => 60
      }
    rescue
      {
        'amount_tolerance_pct' => 2.0,
        'date_tolerance_days' => 3,
        'customer_fuzzy_minimum' => 0.80,
        'reference_weight' => 15,
        'auto_post_threshold' => 95,
        'suggestion_threshold' => 85,
        'rejection_window_minutes' => 60
      }
    end

    def amount_description
      amount_diff = (@bank_transaction.amount - @matching_invoice.total).abs
      pct_diff = (@matching_invoice.total.to_f > 0) ? 
        ((amount_diff / @matching_invoice.total.to_f) * 100).round(2) : 
        0

      if pct_diff == 0
        "Exact match (₹#{@bank_transaction.amount.round(2)})"
      else
        "Difference: ₹#{amount_diff.round(2)} (#{pct_diff}%)"
      end
    rescue
      "Amount analysis unavailable"
    end

    def date_description
      date_diff = (@bank_transaction.date - @matching_invoice.issue_date.to_date).abs
      
      case date_diff
      when 0
        "Same day"
      when 1
        "±1 day"
      else
        "±#{date_diff} days"
      end
    rescue
      "Date analysis unavailable"
    end

    def customer_description
      similarity = fuzzy_match_score(
        @bank_transaction.customer_name,
        @matching_invoice.customer.name
      )
      
      pct = (similarity * 100).round(0)
      "#{pct}% fuzzy match"
    rescue
      "Customer analysis unavailable"
    end

    def reference_description
      references = [
        @matching_invoice.invoice_number,
        @matching_invoice.order&.order_number
      ].compact

      if references.any? { |ref| @bank_transaction.reference.to_s.upcase.include?(ref.to_s.upcase) }
        matched_ref = references.find { |ref| @bank_transaction.reference.to_s.upcase.include?(ref.to_s.upcase) }
        "#{matched_ref} found in reference"
      else
        "No reference match"
      end
    rescue
      "Reference analysis unavailable"
    end
  end
end
