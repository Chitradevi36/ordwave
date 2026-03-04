module Products
  # Looks up the current master details for a given HSN/SAC code.
  #
  # Intended to be called when a product's HSN code is set/changed so that
  # the GST rate and description can be pre-filled automatically.
  #
  # Usage:
  #   result = Products::HsnLookupService.lookup('1006')
  #   result[:gst_rate]   # => 5
  #   result[:warning]    # => nil  (or message if code not found)
  #
  class HsnLookupService
    # @param code [String] HSN or SAC code
    # @return [Hash]
    def self.lookup(code)
      return { warning: 'HSN/SAC code is required' } if code.to_s.strip.blank?

      hsn = HsnSacCode.current.by_code(code).first

      unless hsn
        return {
          code:    code.to_s.strip.upcase,
          warning: "HSN/SAC code '#{code.to_s.strip.upcase}' not found in master"
        }
      end

      {
        code:        hsn.code,
        code_type:   hsn.code_type,
        description: hsn.description,
        chapter:     hsn.chapter,
        gst_rate:    hsn.gst_rate,
        cgst_rate:   hsn.cgst_rate,
        sgst_rate:   hsn.sgst_rate,
        igst_rate:   hsn.igst_rate
      }
    end
  end
end
