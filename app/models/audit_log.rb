# Append-only record of changes (FR-4). Entries cannot be changed or deleted.
class AuditLog < ApplicationRecord
  belongs_to :actor, class_name: "User", optional: true

  validates :occurred_at, :action, :entity_type, :entity_id, presence: true

  def readonly?
    persisted? || super
  end
end
