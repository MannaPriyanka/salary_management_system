require "rails_helper"

RSpec.describe SyntheticSeed do
  let(:count) { 60 }

  before { create(:user) }

  it "is configured for 10,000 employees by default" do
    expect(SyntheticSeed::DEFAULT_EMPLOYEE_COUNT).to eq(10_000)
  end

  it "creates the requested number of employees with valid relationships" do
    described_class.call(employee_count: count)

    expect(Employee.count).to eq(count)
    expect(Employee.where(department_id: nil).or(Employee.where(country_id: nil))).to be_empty
    expect(Employee.pluck(:employee_code).uniq.size).to eq(count)
    expect(Employee.pluck(:work_email).map(&:downcase).uniq.size).to eq(count)
  end

  it "is repeatable: a second run creates no duplicates and changes nothing" do
    described_class.call(employee_count: count)
    first = [ Employee.count, SalaryRevision.count, Employee.order(:employee_code).pluck(:full_name, :work_email) ]

    described_class.call(employee_count: count)
    second = [ Employee.count, SalaryRevision.count, Employee.order(:employee_code).pluck(:full_name, :work_email) ]

    expect(second).to eq(first)
  end

  it "generates the same data for the same seed" do
    described_class.call(employee_count: count, seed: 7)
    names = Employee.order(:employee_code).pluck(:full_name)
    SalaryRevision.delete_all
    Employee.delete_all
    described_class.call(employee_count: count, seed: 7)
    expect(Employee.order(:employee_code).pluck(:full_name)).to eq(names)
  end

  it "gives every salary revision a currency that is enabled, and uses several currencies" do
    described_class.call(employee_count: count)

    currencies = SalaryRevision.distinct.pluck(:currency_code)
    expect(currencies).to all(be_in(%w[INR USD EUR GBP]))
    expect(currencies.size).to be > 1
  end

  it "creates revisions that respect each employee's joining and exit dates" do
    described_class.call(employee_count: count)

    SalaryRevision.includes(:employee).find_each do |revision|
      expect(revision.effective_date).to be >= revision.employee.joining_date
      expect(revision.effective_date).to be <= Date.current
      if revision.employee.exit_date
        expect(revision.effective_date).to be <= revision.employee.exit_date
      end
    end
  end

  it "keeps every employee's current salary valid under the model rules" do
    described_class.call(employee_count: count)
    expect(SalaryRevision.all.all?(&:valid?)).to be(true)
  end
end
