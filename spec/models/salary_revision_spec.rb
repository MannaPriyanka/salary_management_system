require "rails_helper"

RSpec.describe SalaryRevision, type: :model do
  subject(:revision) { build(:salary_revision) }

  it { is_expected.to belong_to(:employee) }
  it { is_expected.to belong_to(:recorded_by).class_name("User") }
  it { is_expected.to have_many(:revision_components) }

  describe "amount" do
    it "must be greater than zero" do
      revision.base_amount = BigDecimal("0")
      expect(revision).to be_invalid
      expect(revision.errors[:base_amount]).to be_present
    end

    it "accepts two decimal places for INR" do
      revision.base_amount = BigDecimal("125000.55")
      expect(revision).to be_valid
    end

    it "rejects more decimal places than the currency allows, without rounding" do
      revision.base_amount = BigDecimal("1000.005")
      expect(revision).to be_invalid
      expect(revision.errors[:base_amount].join).to match(/2 decimal places/)
    end

    it "accepts trailing zeros beyond the allowed places" do
      revision.base_amount = BigDecimal("1000.500")
      expect(revision).to be_valid
    end

    it "accepts zero decimal places for a zero-decimal currency" do
      create(:currency, code: "JPY", minor_units: 0, enabled: true)
      revision.currency_code = "JPY"
      revision.base_amount = BigDecimal("500")
      expect(revision).to be_valid
      revision.base_amount = BigDecimal("500.5")
      expect(revision).to be_invalid
    end
  end

  describe "currency" do
    it "must exist and be enabled" do
      create(:currency, code: "CHF", minor_units: 2, enabled: false)
      revision.currency_code = "CHF"
      expect(revision).to be_invalid
      expect(revision.errors[:currency_code]).to be_present
    end

    it "must exist in the currency table" do
      revision.currency_code = "ZZZ"
      expect(revision).to be_invalid
    end
  end

  describe "effective date" do
    it "is required" do
      revision.effective_date = nil
      expect(revision).to be_invalid
    end

    it "cannot be before the joining date" do
      revision.employee = create(:employee, joining_date: Date.new(2021, 1, 1))
      revision.effective_date = Date.new(2020, 12, 31)
      expect(revision).to be_invalid
      expect(revision.errors[:effective_date]).to be_present
    end

    it "equal to the joining date is accepted" do
      revision.employee = create(:employee, joining_date: Date.new(2021, 1, 1))
      revision.effective_date = Date.new(2021, 1, 1)
      expect(revision).to be_valid
    end

    it "cannot be after the exit date" do
      employee = create(:employee, :exited, joining_date: Date.new(2020, 1, 1), exit_date: Date.new(2024, 6, 30))
      revision.employee = employee
      revision.effective_date = Date.new(2024, 7, 1)
      expect(revision).to be_invalid
    end

    it "is unique per employee" do
      existing = create(:salary_revision, effective_date: Date.new(2021, 1, 1))
      duplicate = build(:salary_revision, employee: existing.employee, effective_date: Date.new(2021, 1, 1))
      expect(duplicate).to be_invalid
    end

    it "is unique per employee at database level" do
      existing = create(:salary_revision, effective_date: Date.new(2021, 1, 1))
      expect {
        SalaryRevision.insert_all!([ {
          employee_id: existing.employee_id, currency_code: "INR", base_amount: 1, effective_date: existing.effective_date,
          recorded_by_id: existing.recorded_by_id, created_at: Time.current, updated_at: Time.current
        } ])
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "append-only behaviour" do
    it "cannot be updated after creation" do
      record = create(:salary_revision)
      expect { record.update!(reason: "Changed") }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it "cannot be destroyed" do
      record = create(:salary_revision)
      expect { record.destroy! }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end
  end
end
