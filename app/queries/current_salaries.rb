# Current salary revision for many employees in one query (no N+1).
# The current revision is the latest one effective on or before the given date.
class CurrentSalaries
  def self.for(employee_ids, on: Date.current)
    return {} if employee_ids.empty?

    SalaryRevision
      .includes(:currency)
      .where(employee_id: employee_ids)
      .where(effective_date: ..on)
      .select("DISTINCT ON (salary_revisions.employee_id) salary_revisions.*")
      .order(Arel.sql("salary_revisions.employee_id, salary_revisions.effective_date DESC"))
      .index_by(&:employee_id)
  end
end
