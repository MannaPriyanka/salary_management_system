module Api
  module V1
    class AuditEntriesController < ApplicationController
      PER_PAGE = 50

      def index
        employee = Employee.find(params[:employee_id])
        revision_ids = employee.salary_revisions.pluck(:id).map(&:to_s)

        scope = AuditLog.includes(:actor)
                        .where(entity_type: "Employee", entity_id: employee.id.to_s)
                        .or(AuditLog.includes(:actor).where(entity_type: "SalaryRevision", entity_id: revision_ids))
                        .order(occurred_at: :desc, id: :desc)
        page = [ params.fetch(:page, 1).to_i, 1 ].max
        entries = scope.limit(PER_PAGE).offset((page - 1) * PER_PAGE)

        render json: { data: entries.map { |entry| entry_json(entry) }, meta: { page: page, per_page: PER_PAGE } }
      end

      private

      def entry_json(entry)
        {
          occurred_at: entry.occurred_at.iso8601,
          actor: entry.actor && { id: entry.actor.id, email: entry.actor.email },
          action: entry.action,
          entity_type: entry.entity_type,
          entity_id: entry.entity_id,
          previous_values: entry.previous_values,
          new_values: entry.new_values
        }
      end
    end
  end
end
