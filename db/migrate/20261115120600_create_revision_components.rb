class CreateRevisionComponents < ActiveRecord::Migration[8.1]
  def up
    return if table_exists?(:revision_components)

    create_table :revision_components do |t|
      t.bigint :salary_revision_id, null: false
      t.string :component_type, null: false
      t.string :currency_code, null: false, limit: 3
      t.decimal :amount, precision: 18, scale: 4, null: false
      t.timestamps
    end

    add_foreign_key :revision_components, :salary_revisions unless foreign_key_exists?(:revision_components, :salary_revisions)
    add_foreign_key :revision_components, :currencies, column: :currency_code, primary_key: :code unless foreign_key_exists?(:revision_components, :currencies, column: :currency_code)

    add_index :revision_components, [ :salary_revision_id, :component_type ], unique: true,
      name: "index_components_on_revision_and_type", if_not_exists: true
    add_check_constraint :revision_components, "component_type IN ('allowance', 'bonus')", name: "component_type_values"
    add_check_constraint :revision_components, "amount > 0", name: "component_amount_positive"
  end

  def down
    drop_table :revision_components, if_exists: true
  end
end
