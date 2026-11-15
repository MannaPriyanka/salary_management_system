class CreateUsers < ActiveRecord::Migration[8.1]
  def up
    return if table_exists?(:users)

    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.integer :failed_attempts, null: false, default: 0
      t.datetime :first_failed_at
      t.datetime :refusal_until
      t.timestamps
    end
    add_index :users, :email, unique: true, if_not_exists: true
  end

  def down
    drop_table :users, if_exists: true
  end
end
