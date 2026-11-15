require "rails_helper"

RSpec.describe Employee, type: :model do
  subject(:employee) { build(:employee) }

  it { is_expected.to belong_to(:department) }
  it { is_expected.to belong_to(:designation) }
  it { is_expected.to belong_to(:country) }
  it { is_expected.to have_many(:salary_revisions).dependent(:restrict_with_error) }

  describe "uniqueness" do
    before { create(:employee, employee_code: "EMP00001", work_email: "a@example.test") }

    it "rejects a duplicate employee code" do
      duplicate = build(:employee, employee_code: "EMP00001", work_email: "b@example.test")
      expect(duplicate).to be_invalid
      expect(duplicate.errors[:employee_code]).to be_present
    end

    it "rejects a duplicate work email regardless of case" do
      duplicate = build(:employee, work_email: "A@Example.TEST")
      expect(duplicate).to be_invalid
      expect(duplicate.errors[:work_email]).to be_present
    end

    it "stores work email in lower case" do
      record = create(:employee, work_email: "Mixed.Case@Example.TEST")
      expect(record.reload.work_email).to eq("mixed.case@example.test")
    end
  end

  describe "employee code" do
    it "cannot change after creation" do
      record = create(:employee, employee_code: "EMP00002")
      record.employee_code = "EMP99999"
      expect(record).to be_invalid
      expect(record.errors[:employee_code]).to be_present
    end
  end

  describe "employment status" do
    it { is_expected.to validate_inclusion_of(:employment_status).in_array(%w[active on_leave exited]) }
  end

  describe "exit date" do
    it "is required when the employee has exited" do
      employee.employment_status = "exited"
      employee.exit_date = nil
      expect(employee).to be_invalid
      expect(employee.errors[:exit_date]).to be_present
    end

    it "must be after the joining date" do
      employee.employment_status = "exited"
      employee.exit_date = employee.joining_date
      expect(employee).to be_invalid
    end
  end

  describe "archiving" do
    it "is allowed for an exited employee" do
      record = create(:employee, :exited)
      record.archive!
      expect(record.reload).to be_archived
    end

    it "is refused for an active employee" do
      record = create(:employee)
      expect { record.archive! }.to raise_error(ActiveRecord::RecordInvalid)
      expect(record.reload).not_to be_archived
    end

    it "keeps salary revisions when archived" do
      record = create(:employee, :exited)
      revision = create(:salary_revision, employee: record, effective_date: Date.new(2021, 1, 1))
      record.archive!
      expect(revision.reload.employee).to eq(record)
    end

    it "is enforced by the database for active employees" do
      record = create(:employee)
      expect {
        record.update_column(:archived_at, Time.current)
      }.to raise_error(ActiveRecord::StatementInvalid, /archived_only_when_exited/)
    end
  end

  describe "joining date rule" do
    it "is rejected when an existing revision would fall before the new joining date" do
      record = create(:employee, joining_date: Date.new(2020, 1, 1))
      create(:salary_revision, employee: record, effective_date: Date.new(2021, 6, 1))
      record.joining_date = Date.new(2021, 7, 1)
      expect(record).to be_invalid
      expect(record.errors[:joining_date]).to be_present
    end

    it "is accepted when every revision remains on or after the new date" do
      record = create(:employee, joining_date: Date.new(2020, 1, 1))
      create(:salary_revision, employee: record, effective_date: Date.new(2021, 6, 1))
      record.joining_date = Date.new(2021, 6, 1)
      expect(record).to be_valid
    end

    it "is accepted when moved earlier" do
      record = create(:employee, joining_date: Date.new(2020, 1, 1))
      create(:salary_revision, employee: record, effective_date: Date.new(2021, 6, 1))
      record.joining_date = Date.new(2019, 1, 1)
      expect(record).to be_valid
    end
  end

  describe "#current_salary_revision" do
    let(:record) { create(:employee, joining_date: Date.new(2020, 1, 1)) }

    it "returns nil when no revision is in force" do
      expect(record.current_salary_revision(on: Date.new(2021, 1, 1))).to be_nil
    end

    it "returns the latest revision effective on or before the date" do
      create(:salary_revision, employee: record, effective_date: Date.new(2021, 1, 1))
      latest = create(:salary_revision, employee: record, effective_date: Date.new(2022, 1, 1))
      create(:salary_revision, employee: record, effective_date: Date.new(2023, 1, 1))

      expect(record.current_salary_revision(on: Date.new(2022, 6, 1))).to eq(latest)
    end
  end
end
