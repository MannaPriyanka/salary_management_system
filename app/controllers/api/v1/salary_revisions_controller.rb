module Api
  module V1
    class SalaryRevisionsController < ApplicationController
      rescue_from InvalidAmount do |error|
        render_error(:unprocessable_content, "validation_failed", "One or more fields are invalid.",
                     [ { field: "base_amount", message: error.message } ])
      end

      def index
        employee = Employee.find(params[:employee_id])
        order = params[:order] == "effective_desc" ? { effective_date: :desc } : { effective_date: :asc }
        revisions = employee.salary_revisions.includes(:currency, :recorded_by, :revision_components).order(order)
        render json: { data: revisions.map { |revision| revision_json(revision) } }
      end

      def create
        employee = Employee.find(params[:employee_id])
        revision = nil

        Employee.transaction do
          employee.lock!
          revision = employee.salary_revisions.new(revision_attributes)
          revision.recorded_by = current_user
          build_components(revision)
          revision.save!
        end

        render json: { data: revision_json(revision) }, status: :created
      rescue ActiveRecord::RecordInvalid => error
        render_revision_errors(error.record)
      rescue ActiveRecord::RecordNotUnique
        render_error(:conflict, "effective_date_conflict", "A salary revision already exists for this effective date.")
      end

      private

      def revision_attributes
        {
          currency_code: params[:currency].to_s.strip.upcase,
          base_amount: parse_amount(params[:base_amount]),
          effective_date: params[:effective_date],
          reason: params[:reason]
        }
      end

      def build_components(revision)
        Array(params[:components]).each do |component|
          revision.revision_components.build(
            component_type: component[:type].to_s,
            amount: parse_amount(component[:amount]),
            currency_code: component[:currency].presence&.upcase || revision.currency_code
          )
        end
      end

      def render_revision_errors(revision)
        if revision.errors.of_kind?(:effective_date, :taken)
          return render_error(:conflict, "effective_date_conflict", "A salary revision already exists for this effective date.")
        end

        render_validation_errors(revision)
      end

      def revision_json(revision)
        minor_units = revision.currency.minor_units
        {
          id: revision.id,
          currency: revision.currency_code,
          base_amount: Money.to_json_string(revision.base_amount, minor_units),
          effective_date: revision.effective_date.to_s,
          reason: revision.reason,
          recorded_by: { id: revision.recorded_by.id, email: revision.recorded_by.email },
          recorded_at: revision.created_at.iso8601,
          components: revision.revision_components.map do |component|
            { type: component.component_type,
              amount: Money.to_json_string(component.amount, minor_units),
              currency: component.currency_code }
          end
        }
      end
    end
  end
end
