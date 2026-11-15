# Writes audit entries for create and update events (FR-4). Called from model callbacks,
# so every change is recorded in the same transaction as the change itself.
module AuditRecorder
  IGNORED_ATTRIBUTES = %w[created_at updated_at].freeze

  module_function

  def created(record, extra_new_values: {})
    write(record, "create", previous: nil, current: changed_values(record).merge(extra_new_values))
  end

  def updated(record)
    changes = record.saved_changes.except(*IGNORED_ATTRIBUTES)
    write(record, "update",
          previous: changes.transform_values(&:first),
          current: changes.transform_values(&:last))
  end

  def changed_values(record)
    record.saved_changes.except(*IGNORED_ATTRIBUTES).transform_values(&:last)
  end

  def write(record, action, previous:, current:)
    AuditLog.create!(
      actor: Current.user,
      action: action,
      entity_type: record.class.name,
      entity_id: record.id.to_s,
      occurred_at: Time.current,
      previous_values: previous,
      new_values: current
    )
  end
end
