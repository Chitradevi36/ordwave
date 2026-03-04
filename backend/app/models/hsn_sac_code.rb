class HsnSacCode < ApplicationRecord
  VALID_RATES = [0, 5, 12, 18, 28].freeze
  CODE_TYPES  = %w[HSN SAC].freeze

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
  validate  :effective_to_after_effective_from, if: -> { effective_to.present? }

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
    "#{code} – #{description.presence || 'No description'} (#{gst_rate}%)"
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
end
