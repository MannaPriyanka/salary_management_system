module Api
  module V1
    class EmployeesController < ApplicationController
      DEFAULT_PER_PAGE = 25
      MAX_PER_PAGE = 100

      def index
        scope = EmployeeSearch.new(params).call
        total = scope.count
        per_page = params.fetch(:per_page, DEFAULT_PER_PAGE).to_i.clamp(1, MAX_PER_PAGE)
        page = [ params.fetch(:page, 1).to_i, 1 ].max
        employees = scope.limit(per_page).offset((page - 1) * per_page).to_a
        current = CurrentSalaries.for(employees.map(&:id))

        render json: {
          data: employees.map { |employee| employee_json(employee, current[employee.id]) },
          meta: { page: page, per_page: per_page, total_count: total, total_pages: (total.to_f / per_page).ceil }
        }
      end

      def show
        employee = Employee.includes(:department, :designation, :country).find(params[:id])
        render json: { data: employee_json(employee, CurrentSalaries.for([ employee.id ])[employee.id]) }
      end

      def create
        employee = Employee.new(employee_params)
        if employee.save
          render json: { data: employee_json(employee, nil) }, status: :created
        else
          render_employee_errors(employee)
        end
      end

      def update
        employee = Employee.find(params[:id])
        if employee.update(employee_params)
          render json: { data: employee_json(employee, CurrentSalaries.for([ employee.id ])[employee.id]) }
        else
          render_employee_errors(employee)
        end
      end

      def archive
        employee = Employee.find(params[:id])
        unless employee.exited?
          return render_error(:unprocessable_content, "not_exited", "Only exited employees can be archived.")
        end

        employee.archive!
        render json: { data: employee_json(employee, nil) }
      end

      def unarchive
        employee = Employee.find(params[:id])
        employee.update!(archived_at: nil)
        render json: { data: employee_json(employee, nil) }
      end

      private

      def employee_params
        params.permit(:employee_code, :full_name, :work_email, :department_id, :designation_id,
                      :country_id, :employment_status, :joining_date, :exit_date)
      end

      def render_employee_errors(employee)
        if employee.errors.of_kind?(:employee_code, :taken) || employee.errors.of_kind?(:work_email, :taken)
          return render_duplicate(employee)
        end
        if employee.errors.of_kind?(:joining_date, :conflicts_with_revision)
          return render_joining_date_conflict(employee)
        end

        render_validation_errors(employee)
      end

      def render_duplicate(employee)
        existing = Employee.where.not(id: employee.id)
                           .where(employee_code: employee.employee_code)
                           .or(Employee.where.not(id: employee.id).where(work_email: employee.work_email))
                           .first
        details = [ { field: "employee_code_or_work_email", code: "duplicate_identifier",
                     existing_employee_id: existing&.id,
                     message: "An employee with this code or work email already exists." } ]
        render_error(:conflict, "duplicate_identifier", "This employee code or work email is already in use.", details)
      end

      def render_joining_date_conflict(employee)
        conflicts = employee.salary_revisions.where(effective_date: ...employee.joining_date).order(:effective_date)
        details = conflicts.map do |revision|
          { field: "joining_date", code: "revision_before_joining_date",
            revision_id: revision.id, revision_effective_date: revision.effective_date.to_s,
            message: "Salary revision effective #{revision.effective_date} would fall before the new joining date." }
        end
        render_error(:unprocessable_content, "validation_failed", "The joining date conflicts with existing salary revisions.", details)
      end

      def employee_json(employee, current)
        {
          id: employee.id,
          employee_code: employee.employee_code,
          full_name: employee.full_name,
          work_email: employee.work_email,
          department: { id: employee.department.id, name: employee.department.name },
          designation: { id: employee.designation.id, name: employee.designation.name },
          country: { id: employee.country.id, name: employee.country.name, code: employee.country.code },
          employment_status: employee.employment_status,
          joining_date: employee.joining_date.to_s,
          exit_date: employee.exit_date&.to_s,
          archived: employee.archived?,
          current_salary: current && Money.to_json_string(current.base_amount, current.currency.minor_units),
          current_currency: current&.currency_code
        }
      end
    end
  end
end
