class CreateSalaryRevisions < ActiveRecord::Migration[8.1]
  def up
    return if table_exists?(:salary_revisions)

    create_table :salary_revisions do |t|
      t.bigint :employee_id, null: false
      t.string :currency_code, null: false, limit: 3
      t.decimal :base_amount, precision: 18, scale: 4, null: false
      t.date :effective_date, null: false
      t.string :reason, limit: 500
      t.bigint :recorded_by_id, null: false
      t.timestamps
    end

    add_foreign_key :salary_revisions, :employees unless foreign_key_exists?(:salary_revisions, :employees)
    add_foreign_key :salary_revisions, :users, column: :recorded_by_id unless foreign_key_exists?(:salary_revisions, :users, column: :recorded_by_id)
    add_foreign_key :salary_revisions, :currencies, column: :currency_code, primary_key: :code unless foreign_key_exists?(:salary_revisions, :currencies, column: :currency_code)

    add_index :salary_revisions, [ :employee_id, :effective_date ], unique: true, if_not_exists: true
    add_check_constraint :salary_revisions, "base_amount > 0", name: "base_amount_positive"
  end

  def down
    drop_table :salary_revisions, if_exists: true
  end
end
