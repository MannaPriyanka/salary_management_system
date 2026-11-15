class CreateCurrencies < ActiveRecord::Migration[8.1]
  def up
    return if table_exists?(:currencies)

    create_table :currencies do |t|
      t.string :code, null: false, limit: 3
      t.string :name, null: false
      t.integer :minor_units, null: false
      t.boolean :enabled, null: false, default: false
      t.timestamps
    end

    add_index :currencies, :code, unique: true, if_not_exists: true
    add_check_constraint :currencies, "code ~ '^[A-Z]{3}$'", name: "currency_code_format"
    add_check_constraint :currencies, "minor_units BETWEEN 0 AND 4", name: "currency_minor_units_range"
  end

  def down
    drop_table :currencies, if_exists: true
  end
end
