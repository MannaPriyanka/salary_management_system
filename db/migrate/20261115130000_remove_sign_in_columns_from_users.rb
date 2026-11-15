class RemoveSignInColumnsFromUsers < ActiveRecord::Migration[8.1]
  # Sign-in protection state lives in the cache, keyed by the email, so that it also
  # applies to unknown emails without revealing which accounts exist.
  def up
    remove_column :users, :failed_attempts if column_exists?(:users, :failed_attempts)
    remove_column :users, :first_failed_at if column_exists?(:users, :first_failed_at)
    remove_column :users, :refusal_until if column_exists?(:users, :refusal_until)
  end

  def down
    add_column :users, :failed_attempts, :integer, null: false, default: 0 unless column_exists?(:users, :failed_attempts)
    add_column :users, :first_failed_at, :datetime unless column_exists?(:users, :first_failed_at)
    add_column :users, :refusal_until, :datetime unless column_exists?(:users, :refusal_until)
  end
end
