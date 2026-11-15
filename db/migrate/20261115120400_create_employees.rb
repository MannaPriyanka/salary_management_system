class CreateEmployees < ActiveRecord::Migration[8.1]
  def up
    return if table_exists?(:employees)

    create_table :employees do |t|
      t.string :employee_code, null: false
      t.string :full_name, null: false
      t.string :work_email, null: false
      t.bigint :department_id, null: false
      t.bigint :designation_id, null: false
      t.bigint :country_id, null: false
      t.string :employment_status, null: false, default: "active"
      t.date :joining_date, null: false
      t.date :exit_date
      t.datetime :archived_at
      t.timestamps
    end

    add_foreign_key :employees, :departments unless foreign_key_exists?(:employees, :departments)
    add_foreign_key :employees, :designations unless foreign_key_exists?(:employees, :designations)
    add_foreign_key :employees, :countries unless foreign_key_exists?(:employees, :countries)

    add_index :employees, :employee_code, unique: true, if_not_exists: true
    add_index :employees, "lower(work_email)", unique: true, name: "index_employees_on_lower_work_email", if_not_exists: true

    add_check_constraint :employees,
      "employment_status IN ('active', 'on_leave', 'exited')",
      name: "employment_status_values"
    add_check_constraint :employees,
      "employment_status <> 'exited' OR exit_date IS NOT NULL",
      name: "exited_requires_exit_date"
    add_check_constraint :employees,
      "exit_date IS NULL OR exit_date > joining_date",
      name: "exit_date_after_joining_date"
    add_check_constraint :employees,
      "archived_at IS NULL OR employment_status = 'exited'",
      name: "archived_only_when_exited"
  end

  def down
    drop_table :employees, if_exists: true
  end
end
