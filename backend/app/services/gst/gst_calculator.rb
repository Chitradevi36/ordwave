module Gst
  # Calculates CGST/SGST (intra-state) or IGST (inter-state) for a transaction.
  #
  # Usage:
  #   result = Gst::GstCalculator.calculate(
  #     branch:         branch,
  #     customer:       customer,
  #     gst_rate:       18,
  #     taxable_value:  1000
  #   )
  #   result.igst_amount   # => 0 (intra) or 180 (inter)
  #   result.cgst_amount   # => 90  (intra) or 0 (inter)
  #
  class GstCalculator
    Result = Struct.new(
      :intra_state,
      :cgst_rate,   :sgst_rate,   :igst_rate,
      :cgst_amount, :sgst_amount, :igst_amount,
      :total_tax,
      keyword_init: true
    )

    # @param branch         [Branch]   selling branch (must respond to #state_code)
    # @param customer       [Customer] buying customer (must respond to #gstin)
    # @param gst_rate       [Numeric]  combined GST rate (0/5/12/18/28)
    # @param taxable_value  [Numeric]  pre-tax line value in organisation currency
    # @return [Result]
    def self.calculate(branch:, customer:, gst_rate:, taxable_value:)
      new(branch: branch, customer: customer,
          gst_rate: gst_rate, taxable_value: taxable_value).call
    end

    private_class_method :new

    def initialize(branch:, customer:, gst_rate:, taxable_value:)
      @branch_state_code   = branch&.state_code.to_s.strip
      @customer_state_code = customer&.gstin.to_s.strip.first(2)
      @gst_rate            = BigDecimal(gst_rate.to_s)
      @taxable_value       = BigDecimal(taxable_value.to_s)
    end

    def call
      if intra_state?
        half = (@gst_rate / 2).round(2)
        cgst_rate = half
        sgst_rate = half
        igst_rate = BigDecimal('0')
      else
        cgst_rate = BigDecimal('0')
        sgst_rate = BigDecimal('0')
        igst_rate = @gst_rate
      end

      cgst_amount = (@taxable_value * cgst_rate / 100).round(2)
      sgst_amount = (@taxable_value * sgst_rate / 100).round(2)
      igst_amount = (@taxable_value * igst_rate / 100).round(2)

      Result.new(
        intra_state:  intra_state?,
        cgst_rate:    cgst_rate,
        sgst_rate:    sgst_rate,
        igst_rate:    igst_rate,
        cgst_amount:  cgst_amount,
        sgst_amount:  sgst_amount,
        igst_amount:  igst_amount,
        total_tax:    (cgst_amount + sgst_amount + igst_amount).round(2)
      )
    end

    private

    # Two transactions are intra-state when BOTH state codes are present and match.
    # If either code is blank (branch missing state_code, or customer has no GSTIN),
    # we treat conservatively as intra-state (split taxes) to avoid over-charging IGST.
    def intra_state?
      return @intra_state_cache if defined?(@intra_state_cache)

      @intra_state_cache =
        @branch_state_code.blank? ||
        @customer_state_code.blank? ||
        @branch_state_code == @customer_state_code
    end
  end
end
