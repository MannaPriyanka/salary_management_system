# A salary revision is append-only (D-05). Once saved it cannot be changed or deleted.
class SalaryRevision < ApplicationRecord
  belongs_to :employee
  belongs_to :recorded_by, class_name: "User"
  belongs_to :currency, primary_key: :code, foreign_key: :currency_code, inverse_of: false
  has_many :revision_components

  validates :base_amount, presence: true, numericality: { greater_than: 0 }
  validates :effective_date, presence: true, uniqueness: { scope: :employee_id }
  validate :currency_is_enabled
  validate :amount_precision_matches_currency
  validate :effective_date_within_employment

  def readonly?
    persisted? || super
  end

  private

  def currency_is_enabled
    return if currency.nil? || currency.enabled?

    errors.add(:currency_code, "is not enabled")
  end

  def amount_precision_matches_currency
    return if base_amount.blank? || currency.nil?
    return if Money.within_precision?(base_amount, currency.minor_units)

    errors.add(:base_amount, "must have at most #{currency.minor_units} decimal places")
  end

  def effective_date_within_employment
    return if employee.nil? || effective_date.blank?

    if employee.joining_date && effective_date < employee.joining_date
      errors.add(:effective_date, "cannot be before the joining date (#{employee.joining_date})")
    end
    return unless employee.exited? && employee.exit_date && effective_date > employee.exit_date

    errors.add(:effective_date, "cannot be after the exit date (#{employee.exit_date})")
  end
end
