# Per-request context, used by the audit trail to record who made a change.
class Current < ActiveSupport::CurrentAttributes
  attribute :user
end
