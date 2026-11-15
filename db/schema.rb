# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_15_120700) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "audit_logs", force: :cascade do |t|
    t.datetime "occurred_at", null: false
    t.bigint "actor_id"
    t.string "action", null: false
    t.string "entity_type", null: false
    t.string "entity_id", null: false
    t.jsonb "previous_values"
    t.jsonb "new_values"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_audit_logs_on_actor_id"
    t.index ["entity_type", "entity_id", "occurred_at"], name: "index_audit_logs_on_entity_type_and_entity_id_and_occurred_at"
  end

  create_table "countries", force: :cascade do |t|
    t.string "code", null: false
    t.string "name", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((code)::text)", name: "index_countries_on_lower_code", unique: true
    t.index "lower((name)::text)", name: "index_countries_on_lower_name", unique: true
  end

  create_table "currencies", force: :cascade do |t|
    t.string "code", limit: 3, null: false
    t.string "name", null: false
    t.integer "minor_units", null: false
    t.boolean "enabled", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_currencies_on_code", unique: true
    t.check_constraint "code::text ~ '^[A-Z]{3}$'::text", name: "currency_code_format"
    t.check_constraint "minor_units >= 0 AND minor_units <= 4", name: "currency_minor_units_range"
  end

  create_table "departments", force: :cascade do |t|
    t.string "name", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "index_departments_on_lower_name", unique: true
  end

  create_table "designations", force: :cascade do |t|
    t.string "name", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "index_designations_on_lower_name", unique: true
  end

  create_table "employees", force: :cascade do |t|
    t.string "employee_code", null: false
    t.string "full_name", null: false
    t.string "work_email", null: false
    t.bigint "department_id", null: false
    t.bigint "designation_id", null: false
    t.bigint "country_id", null: false
    t.string "employment_status", default: "active", null: false
    t.date "joining_date", null: false
    t.date "exit_date"
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((work_email)::text)", name: "index_employees_on_lower_work_email", unique: true
    t.index ["country_id"], name: "index_employees_on_country_id"
    t.index ["department_id"], name: "index_employees_on_department_id"
    t.index ["designation_id"], name: "index_employees_on_designation_id"
    t.index ["employee_code"], name: "index_employees_on_employee_code", unique: true
    t.check_constraint "archived_at IS NULL OR employment_status::text = 'exited'::text", name: "archived_only_when_exited"
    t.check_constraint "employment_status::text <> 'exited'::text OR exit_date IS NOT NULL", name: "exited_requires_exit_date"
    t.check_constraint "employment_status::text = ANY (ARRAY['active'::character varying, 'on_leave'::character varying, 'exited'::character varying]::text[])", name: "employment_status_values"
    t.check_constraint "exit_date IS NULL OR exit_date > joining_date", name: "exit_date_after_joining_date"
  end

  create_table "revision_components", force: :cascade do |t|
    t.bigint "salary_revision_id", null: false
    t.string "component_type", null: false
    t.string "currency_code", limit: 3, null: false
    t.decimal "amount", precision: 18, scale: 4, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["salary_revision_id", "component_type"], name: "index_components_on_revision_and_type", unique: true
    t.index ["salary_revision_id"], name: "index_revision_components_on_salary_revision_id"
    t.check_constraint "amount > 0::numeric", name: "component_amount_positive"
    t.check_constraint "component_type::text = ANY (ARRAY['allowance'::character varying, 'bonus'::character varying]::text[])", name: "component_type_values"
  end

  create_table "salary_revisions", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.string "currency_code", limit: 3, null: false
    t.decimal "base_amount", precision: 18, scale: 4, null: false
    t.date "effective_date", null: false
    t.string "reason", limit: 500
    t.bigint "recorded_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id", "effective_date"], name: "index_salary_revisions_on_employee_id_and_effective_date", unique: true
    t.index ["employee_id"], name: "index_salary_revisions_on_employee_id"
    t.index ["recorded_by_id"], name: "index_salary_revisions_on_recorded_by_id"
    t.check_constraint "base_amount > 0::numeric", name: "base_amount_positive"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.datetime "first_failed_at"
    t.datetime "refusal_until"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "audit_logs", "users", column: "actor_id"
  add_foreign_key "employees", "countries"
  add_foreign_key "employees", "departments"
  add_foreign_key "employees", "designations"
  add_foreign_key "revision_components", "currencies", column: "currency_code", primary_key: "code"
  add_foreign_key "revision_components", "salary_revisions"
  add_foreign_key "salary_revisions", "currencies", column: "currency_code", primary_key: "code"
  add_foreign_key "salary_revisions", "employees"
  add_foreign_key "salary_revisions", "users", column: "recorded_by_id"
end
