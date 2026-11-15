require "rails_helper"

RSpec.describe AuditLog, type: :model do
  it "is created with actor, action, entity, and values" do
    user = create(:user)
    entry = AuditLog.create!(
      actor: user, action: "update", entity_type: "Employee", entity_id: "7",
      previous_values: { "full_name" => "Old" }, new_values: { "full_name" => "New" },
      occurred_at: Time.current
    )
    expect(entry.reload.previous_values).to eq("full_name" => "Old")
  end

  it "cannot be updated" do
    entry = create(:audit_log)
    expect { entry.update!(action: "changed") }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it "cannot be destroyed" do
    entry = create(:audit_log)
    expect { entry.destroy! }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end
end
