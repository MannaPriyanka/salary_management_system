class CreateAuditLogs < ActiveRecord::Migration[8.1]
  def up
    return if table_exists?(:audit_logs)

    create_table :audit_logs do |t|
      t.datetime :occurred_at, null: false
      t.bigint :actor_id
      t.string :action, null: false
      t.string :entity_type, null: false
      t.string :entity_id, null: false
      t.jsonb :previous_values
      t.jsonb :new_values
      t.timestamps
    end

    add_foreign_key :audit_logs, :users, column: :actor_id unless foreign_key_exists?(:audit_logs, :users, column: :actor_id)
    add_index :audit_logs, [ :entity_type, :entity_id, :occurred_at ], if_not_exists: true
  end

  def down
    drop_table :audit_logs, if_exists: true
  end
end
