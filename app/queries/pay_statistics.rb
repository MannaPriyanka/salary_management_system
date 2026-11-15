# Current pay statistics (FR-5). The population is employees who are not archived,
# are employed on the date, and have a salary revision in force on that date.
#
# Median is computed in Ruby with BigDecimal, not in SQL: percentile_cont returns a
# floating-point number, which breaks the exact-decimal rule (ADR-0005).
# Every figure is per currency. Currencies are never added together.
class PayStatistics
  DIMENSIONS = {
    "department" => { column: "employees.department_id", model: Department },
    "country" => { column: "employees.country_id", model: Country },
    "designation" => { column: "employees.designation_id", model: Designation }
  }.freeze

  def initialize(on: Date.current, filters: {})
    @on = on
    @filters = filters
  end

  def summary
    grouped_stats(group_by: []).map do |(currency), amounts|
      stats_row(currency, amounts).merge(group: nil)
    end
  end

  def breakdown(by:)
    dimension = DIMENSIONS.fetch(by) { raise ArgumentError, "unknown breakdown: #{by}" }
    names = dimension[:model].pluck(:id, :name).to_h

    grouped_stats(group_by: [ dimension[:column] ]).map do |(currency, group_id), amounts|
      stats_row(currency, amounts).merge(group: { id: group_id, name: names[group_id] })
    end
  end

  private

  # Returns { [currency, group...] => [BigDecimal amounts] } for the population.
  def grouped_stats(group_by:)
    rows = population.pluck(Arel.sql("cr.currency_code"), *group_by.map { |column| Arel.sql(column) }, Arel.sql("cr.base_amount"))
    rows.each_with_object({}) do |row, groups|
      *keys, amount = row
      (groups[keys.first(1 + group_by.size)] ||= []) << amount
    end.sort_by { |keys, _| keys.map(&:to_s) }
  end

  def population
    current = SalaryRevision
      .where(effective_date: ..@on)
      .select("DISTINCT ON (employee_id) employee_id, currency_code, base_amount")
      .order(Arel.sql("employee_id, effective_date DESC"))

    scope = Employee
      .joins("INNER JOIN (#{current.to_sql}) cr ON cr.employee_id = employees.id")
      .where(archived_at: nil)
      .where("employees.joining_date <= :on AND (employees.exit_date IS NULL OR employees.exit_date >= :on)", on: @on)

    scope = scope.where(department_id: @filters[:department_id]) if @filters[:department_id].present?
    scope = scope.where(country_id: @filters[:country_id]) if @filters[:country_id].present?
    scope = scope.where(designation_id: @filters[:designation_id]) if @filters[:designation_id].present?
    scope
  end

  def stats_row(currency, amounts)
    minor_units = Currency.find_by!(code: currency).minor_units
    sorted = amounts.map { |a| a.to_d }.sort
    total = sorted.sum(BigDecimal("0"))
    count = sorted.size

    {
      currency: currency,
      headcount: count,
      total_base: money(total, minor_units),
      average_base: money(total / count, minor_units),
      median_base: money(median(sorted), minor_units),
      min_base: money(sorted.first, minor_units),
      max_base: money(sorted.last, minor_units),
      as_of: @on.to_s
    }
  end

  def median(sorted)
    middle = sorted.size / 2
    sorted.size.odd? ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
  end

  # Rounds half-up to the currency's decimal places for display only.
  def money(value, minor_units)
    Money.to_json_string(value.round(minor_units), minor_units)
  end
end
