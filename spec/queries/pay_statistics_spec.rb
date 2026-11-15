require "rails_helper"

RSpec.describe PayStatistics do
  let(:today) { Date.new(2026, 11, 15) }
  let(:department) { create(:department, name: "Engineering") }
  let(:other_department) { create(:department, name: "Finance") }

  def hire(amount, currency: "INR", department: self.department, effective: Date.new(2021, 1, 1), **attrs)
    employee = create(:employee, department: department, joining_date: Date.new(2020, 1, 1), **attrs)
    create(:salary_revision, employee: employee, currency_code: currency, base_amount: BigDecimal(amount.to_s), effective_date: effective)
    employee
  end

  subject(:stats) { PayStatistics.new(on: today) }

  describe "#summary" do
    it "returns nothing when there are no employees in force" do
      expect(stats.summary).to eq([])
    end

    it "reports one figure set per currency and never adds currencies together" do
      hire(100_000, currency: "INR")
      hire(2_000, currency: "USD")
      rows = stats.summary.index_by { |r| r[:currency] }

      expect(rows.keys).to contain_exactly("INR", "USD")
      expect(rows["INR"][:total_base]).to eq("100000.00")
      expect(rows["USD"][:total_base]).to eq("2000.00")
    end

    it "computes headcount, total, average, median, minimum, and maximum as exact strings" do
      [ 100_000, 200_000, 400_000 ].each { |amount| hire(amount) }
      row = stats.summary.first

      expect(row).to include(
        currency: "INR", headcount: 3, total_base: "700000.00", average_base: "233333.33",
        median_base: "200000.00", min_base: "100000.00", max_base: "400000.00", as_of: "2026-11-15"
      )
    end

    it "uses the average of the two middle values for an even count" do
      [ 100_000, 200_000, 300_000, 400_000 ].each { |amount| hire(amount) }
      expect(stats.summary.first[:median_base]).to eq("250000.00")
    end

    it "rounds the average half-up to the currency's decimal places" do
      hire("100000.00")
      hire("100000.01")
      expect(stats.summary.first[:average_base]).to eq("100000.01")
    end

    it "uses the revision in force on the date, ignoring future revisions" do
      employee = hire(100_000)
      create(:salary_revision, employee: employee, base_amount: BigDecimal("999999.00"), effective_date: Date.new(2027, 1, 1))
      expect(stats.summary.first[:max_base]).to eq("100000.00")
    end

    it "uses the latest revision already in force" do
      employee = hire(100_000)
      create(:salary_revision, employee: employee, base_amount: BigDecimal("120000.00"), effective_date: Date.new(2025, 1, 1))
      expect(stats.summary.first[:total_base]).to eq("120000.00")
    end

    it "excludes archived, not-yet-joined, employees who left before the date, and employees without a salary" do
      hire(100_000)
      archived = hire(50_000, department: other_department, employee_code: "ARCH1", work_email: "arch@example.test")
      archived.update!(employment_status: "exited", exit_date: Date.new(2026, 1, 1))
      archived.archive!
      create(:employee, joining_date: Date.new(2027, 1, 1)).tap { |e| create(:salary_revision, employee: e, effective_date: Date.new(2027, 1, 1)) }
      left = hire(70_000, work_email: "left@example.test", employee_code: "LEFT1")
      left.update!(employment_status: "exited", exit_date: Date.new(2026, 1, 1))
      create(:employee, employee_code: "NOSAL", work_email: "nosal@example.test")

      expect(stats.summary.first).to include(headcount: 1, total_base: "100000.00")
    end

    it "keeps an employee who left after the date in the population" do
      leaving_later = hire(80_000, work_email: "later@example.test", employee_code: "LATER")
      leaving_later.update!(employment_status: "exited", exit_date: Date.new(2026, 12, 31))
      expect(stats.summary.first[:headcount]).to eq(1)
    end

    it "applies department and country filters" do
      hire(100_000)
      hire(300_000, department: other_department, work_email: "fin@example.test", employee_code: "FIN1")

      expect(PayStatistics.new(on: today, filters: { department_id: other_department.id }).summary.first[:total_base]).to eq("300000.00")
    end
  end

  describe "#breakdown" do
    before do
      hire(100_000)
      hire(300_000, department: other_department, work_email: "fin@example.test", employee_code: "FIN1")
    end

    it "groups by department with the group name" do
      rows = stats.breakdown(by: "department")
      expect(rows.map { |r| [ r[:group][:name], r[:headcount] ] }).to contain_exactly([ "Engineering", 1 ], [ "Finance", 1 ])
      expect(rows.find { |r| r[:group][:name] == "Finance" }[:average_base]).to eq("300000.00")
    end

    it "groups by country and designation" do
      expect(stats.breakdown(by: "country").sum { |r| r[:headcount] }).to eq(2)
      expect(stats.breakdown(by: "designation").sum { |r| r[:headcount] }).to eq(2)
    end

    it "rejects an unknown dimension" do
      expect { stats.breakdown(by: "salary_band") }.to raise_error(ArgumentError)
    end
  end
end
