class CreateReferenceLists < ActiveRecord::Migration[8.1]
  def up
    unless table_exists?(:countries)
      create_table :countries do |t|
        t.string :code, null: false
        t.string :name, null: false
        t.boolean :active, null: false, default: true
        t.timestamps
      end
      add_index :countries, "lower(code)", unique: true, name: "index_countries_on_lower_code", if_not_exists: true
      add_index :countries, "lower(name)", unique: true, name: "index_countries_on_lower_name", if_not_exists: true
    end

    unless table_exists?(:departments)
      create_table :departments do |t|
        t.string :name, null: false
        t.boolean :active, null: false, default: true
        t.timestamps
      end
      add_index :departments, "lower(name)", unique: true, name: "index_departments_on_lower_name", if_not_exists: true
    end

    unless table_exists?(:designations)
      create_table :designations do |t|
        t.string :name, null: false
        t.boolean :active, null: false, default: true
        t.timestamps
      end
      add_index :designations, "lower(name)", unique: true, name: "index_designations_on_lower_name", if_not_exists: true
    end
  end

  def down
    drop_table :designations, if_exists: true
    drop_table :departments, if_exists: true
    drop_table :countries, if_exists: true
  end
end
