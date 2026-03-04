module Gst
  # Resolves the applicable HSN/SAC rate record for a given code and date.
  #
  # Supports historical lookups (e.g. find rate that was valid on a past invoice date)
  # and defaults to the current record when no date is supplied.
  #
  # Usage:
  #   record = Gst::RateResolver.resolve(code: '85171200')
  #   record = Gst::RateResolver.resolve(code: '9963', on_date: Date.new(2022, 4, 1))
  #
  class RateResolver
    # @param code     [String]  HSN or SAC code
    # @param on_date  [Date]    defaults to today
    # @return [HsnSacCode, nil]
    def self.resolve(code:, on_date: Date.current)
      normalised = code.to_s.strip.upcase
      return nil if normalised.blank?

      HsnSacCode
        .where(code: normalised, active: true)
        .where('effective_from <= ?', on_date)
        .where('effective_to IS NULL OR effective_to > ?', on_date)
        .order(effective_from: :desc)
        .first
    end
  end
end
