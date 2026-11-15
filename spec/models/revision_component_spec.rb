require "rails_helper"

RSpec.describe RevisionComponent, type: :model do
  subject(:component) { build(:revision_component) }

  it { is_expected.to belong_to(:salary_revision) }

  it "accepts allowance and bonus types only" do
    expect(build(:revision_component, component_type: "allowance")).to be_valid
    expect(build(:revision_component, component_type: "bonus")).to be_valid
    expect(build(:revision_component, component_type: "stock")).to be_invalid
  end

  it "allows at most one component of each type per revision" do
    existing = create(:revision_component, component_type: "bonus")
    duplicate = build(:revision_component, salary_revision: existing.salary_revision, component_type: "bonus")
    expect(duplicate).to be_invalid
  end

  it "must be greater than zero" do
    component.amount = BigDecimal("0")
    expect(component).to be_invalid
  end

  it "must use the same currency as its revision" do
    revision = create(:salary_revision, currency_code: "INR")
    component.salary_revision = revision
    component.currency_code = "USD"
    expect(component).to be_invalid
    expect(component.errors[:currency_code]).to be_present
  end

  it "follows the same decimal place rule as the revision" do
    component.amount = BigDecimal("10.005")
    expect(component).to be_invalid
  end
end
