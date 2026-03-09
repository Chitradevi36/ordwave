class HsnSacCode < ApplicationRecord
  VALID_RATES = [0, 5, 12, 18, 28].freeze
  CODE_TYPES  = %w[HSN SAC].freeze
  CESS_TYPES  = %w[none ad_valorem specific both].freeze

  # ---------------------------------------------------------------------------
  # Callbacks
  # ---------------------------------------------------------------------------
  before_validation :normalise_code
  before_validation :compute_split_rates

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------
  validates :code,           presence: true
  validates :code_type,      presence: true, inclusion: { in: CODE_TYPES }
  validates :gst_rate,       presence: true,
                             inclusion: { in: VALID_RATES,
                                          message: 'must be one of 0, 5, 12, 18, 28' }
  validates :effective_from, presence: true
  validates :cess_type,      inclusion: { in: CESS_TYPES }, allow_nil: true
  validates :cess_rate,      numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :cess_specific_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate  :effective_to_after_effective_from, if: -> { effective_to.present? }
  validate  :cess_consistency

  # ---------------------------------------------------------------------------
  # Scopes
  # ---------------------------------------------------------------------------
  scope :active,    -> { where(active: true) }
  scope :inactive,  -> { where(active: false) }
  scope :current,   -> { active.where(effective_to: nil) }
  scope :by_code,   ->(code) { where(code: code.to_s.strip.upcase) }
  scope :with_type, ->(type) { where(code_type: type.to_s.upcase) }
  scope :with_rate, ->(rate) { where(gst_rate: rate) }

  # Records whose effective window covers the given date
  scope :effective_on, lambda { |date = Date.current|
    where('effective_from <= ?', date)
      .where('effective_to IS NULL OR effective_to > ?', date)
  }

  # ---------------------------------------------------------------------------
  # Instance helpers
  # ---------------------------------------------------------------------------

  # True only when the record is active and has no end date
  def current_rate?
    active? && effective_to.nil?
  end

  # Friendly label for display
  def display_label
    label = "#{code} – #{description.presence || 'No description'} (#{gst_rate}%)"
    label += " + Cess #{cess_rate}%" if cess_rate.to_d.positive?
    label
  end

  # Returns true if this HSN has any cess configured
  def has_cess?
    cess_type.present? && cess_type != 'none'
  end

  # Calculate cess for a given taxable value and quantity
  # @param taxable_value [Numeric] the taxable value for ad_valorem
  # @param qty [Numeric] quantity for specific cess
  # @return [BigDecimal] total cess amount
  def compute_cess(taxable_value:, qty: 1)
    return BigDecimal('0') unless has_cess?

    ad_valorem_cess = BigDecimal('0')
    specific_cess   = BigDecimal('0')

    if %w[ad_valorem both].include?(cess_type)
      ad_valorem_cess = (BigDecimal(taxable_value.to_s) * BigDecimal(cess_rate.to_s) / 100).round(2)
    end

    if %w[specific both].include?(cess_type)
      specific_cess = (BigDecimal(qty.to_s) * BigDecimal(cess_specific_amount.to_s)).round(2)
    end

    (ad_valorem_cess + specific_cess).round(2)
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------
  private

  def normalise_code
    self.code = code.to_s.strip.upcase if code.present?
  end

  # Derive CGST/SGST/IGST from the combined GST rate.
  # CGST = SGST = gst_rate / 2   (intra-state components)
  # IGST = gst_rate               (inter-state component)
  def compute_split_rates
    return unless gst_rate.present?

    rate           = gst_rate.to_d
    self.igst_rate = rate
    self.cgst_rate = (rate / 2).round(2)
    self.sgst_rate = (rate / 2).round(2)
  end

  def effective_to_after_effective_from
    return unless effective_from.present?

    errors.add(:effective_to, 'must be after effective_from') if effective_to <= effective_from
  end

  # Validate cess_rate presence when cess_type is ad_valorem/both,
  # and cess_specific_amount when cess_type is specific/both
  def cess_consistency
    return if cess_type.blank? || cess_type == 'none'

    if %w[ad_valorem both].include?(cess_type) && cess_rate.to_d.zero?
      errors.add(:cess_rate, 'must be > 0 for ad_valorem/both cess type')
    end

    if %w[specific both].include?(cess_type) && cess_specific_amount.to_d.zero?
      errors.add(:cess_specific_amount, 'must be > 0 for specific/both cess type')
    end
  end
end
