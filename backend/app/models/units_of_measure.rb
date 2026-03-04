class UnitsOfMeasure < ApplicationRecord
  has_many :products, dependent: :restrict_with_error

  # Validations
  validates :name,   presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 50 }
  validates :symbol, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 20 }
  validates :active, inclusion: { in: [true, false] }

  # Scopes
  scope :active, -> { where(active: true) }

  # Common FMCG units (used by seeds/rake task)
  SEEDS = [
    { name: 'Each',       symbol: 'EA' },
    { name: 'Piece',      symbol: 'PC' },
    { name: 'Box',        symbol: 'BOX' },
    { name: 'Carton',     symbol: 'CTN' },
    { name: 'Kilogram',   symbol: 'KG' },
    { name: 'Gram',       symbol: 'GRM' },
    { name: 'Litre',      symbol: 'LTR' },
    { name: 'Millilitre', symbol: 'ML' },
    { name: 'Bag',        symbol: 'BAG' },
    { name: 'Pack',       symbol: 'PACK' },
    { name: 'Case',       symbol: 'CASE' },
    { name: 'Dozen',      symbol: 'DZN' },
  ].freeze
end
