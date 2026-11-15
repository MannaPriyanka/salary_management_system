# Optional allowance or bonus attached to a salary revision. Append-only with its revision.
class RevisionComponent < ApplicationRecord
  TYPES = %w[allowance bonus].freeze

  belongs_to :salary_revision

  validates :component_type, inclusion: { in: TYPES }
  validates :component_type, uniqueness: { scope: :salary_revision_id }
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validate :currency_matches_revision
  validate :amount_precision_matches_currency

  def readonly?
    persisted? || super
  end

  private

  def currency_matches_revision
    return if salary_revision.nil? || currency_code == salary_revision.currency_code

    errors.add(:currency_code, "must match the revision currency (#{salary_revision.currency_code})")
  end

  def amount_precision_matches_currency
    return if amount.blank? || salary_revision.nil?
    return if Money.within_precision?(amount, salary_revision.currency.minor_units)

    errors.add(:amount, "must have at most #{salary_revision.currency.minor_units} decimal places")
  end
end
