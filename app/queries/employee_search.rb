# Filters and search for the employee list. Archived employees are excluded unless asked for.
class EmployeeSearch
  FILTERABLE = %i[department_id designation_id country_id employment_status].freeze

  def initialize(params)
    @params = params
  end

  def call
    scope = Employee.includes(:department, :designation, :country)
    scope = scope.where(archived_at: nil) unless include_archived?
    scope = by_text(scope)
    FILTERABLE.each do |field|
      scope = scope.where(field => @params[field]) if @params[field].present?
    end
    scope.order(:employee_code)
  end

  private

  def include_archived?
    ActiveModel::Type::Boolean.new.cast(@params[:include_archived]) == true
  end

  def by_text(scope)
    return scope if @params[:q].blank?

    term = "%#{Employee.sanitize_sql_like(@params[:q].to_s.strip)}%"
    scope.where("employees.full_name ILIKE :term OR employees.employee_code ILIKE :term", term: term)
  end
end
