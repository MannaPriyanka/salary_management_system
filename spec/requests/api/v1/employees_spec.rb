require "rails_helper"

RSpec.describe "Employees API", type: :request do
  let(:password) { "correct horse battery staple" }
  let(:hr) { create(:user, password: password) }
  let(:department) { create(:department, name: "Engineering") }
  let(:designation) { create(:designation, name: "Engineer") }
  let(:country) { create(:country, code: "IN", name: "India") }

  def sign_in!
    post "/api/v1/session", params: { email: hr.email, password: password }, as: :json
  end

  def employee_params(overrides = {})
    {
      employee_code: "EMP00100",
      full_name: "Asha Rao",
      work_email: "asha.rao@example.test",
      department_id: department.id,
      designation_id: designation.id,
      country_id: country.id,
      employment_status: "active",
      joining_date: "2020-01-15"
    }.merge(overrides)
  end

  before { sign_in! }

  describe "authentication" do
    it "refuses every employee endpoint without a session" do
      delete "/api/v1/session"
      get "/api/v1/employees"
      expect(response).to have_http_status(:unauthorized)

      post "/api/v1/employees", params: employee_params, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/employees" do
    it "creates an employee and returns it" do
      post "/api/v1/employees", params: employee_params, as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig("data", "employee_code")).to eq("EMP00100")
      expect(response.parsed_body.dig("data", "work_email")).to eq("asha.rao@example.test")
      expect(response.parsed_body.dig("data", "department")).to eq("id" => department.id, "name" => "Engineering")
    end

    it "returns 409 for a duplicate employee code and names the existing record" do
      existing = create(:employee, employee_code: "EMP00100")
      post "/api/v1/employees", params: employee_params, as: :json

      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body.dig("error", "code")).to eq("duplicate_identifier")
      expect(response.parsed_body.dig("error", "details", 0, "existing_employee_id")).to eq(existing.id)
    end

    it "returns 409 for a duplicate work email in any case" do
      create(:employee, work_email: "asha.rao@example.test")
      post "/api/v1/employees", params: employee_params(work_email: "ASHA.RAO@example.test"), as: :json
      expect(response).to have_http_status(:conflict)
    end

    it "returns 422 with field details for invalid input" do
      post "/api/v1/employees", params: employee_params(full_name: ""), as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("validation_failed")
      expect(response.parsed_body.dig("error", "details").map { |d| d["field"] }).to include("full_name")
    end

    it "rejects a number for money-free fields with 422 and does not create a record" do
      expect {
        post "/api/v1/employees", params: employee_params(employment_status: "retired"), as: :json
      }.not_to change(Employee, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /api/v1/employees" do
    before do
      create(:employee, full_name: "Ravi Kumar", employee_code: "EMP00001", work_email: "ravi@example.test", department: department)
      create(:employee, full_name: "Meera Shah", employee_code: "EMP00002", work_email: "meera@example.test")
      create(:employee, :exited, full_name: "Old Timer", employee_code: "EMP00003", work_email: "old@example.test")
    end

    it "lists active employees by default with pagination metadata" do
      get "/api/v1/employees"

      expect(response).to have_http_status(:ok)
      names = response.parsed_body["data"].map { |row| row["full_name"] }
      expect(names).to contain_exactly("Ravi Kumar", "Meera Shah", "Old Timer")
      expect(response.parsed_body["meta"]).to include("page" => 1, "per_page" => 25, "total_count" => 3)
    end

    it "hides archived employees unless asked" do
      Employee.find_by(employee_code: "EMP00003").archive!
      get "/api/v1/employees"
      expect(response.parsed_body["data"].map { |r| r["employee_code"] }).not_to include("EMP00003")

      get "/api/v1/employees", params: { include_archived: true }
      expect(response.parsed_body["data"].map { |r| r["employee_code"] }).to include("EMP00003")
    end

    it "searches by name or employee code, case-insensitively" do
      get "/api/v1/employees", params: { q: "ravi" }
      expect(response.parsed_body["data"].map { |r| r["employee_code"] }).to eq([ "EMP00001" ])

      get "/api/v1/employees", params: { q: "emp00002" }
      expect(response.parsed_body["data"].map { |r| r["employee_code"] }).to eq([ "EMP00002" ])
    end

    it "filters by department and employment status" do
      get "/api/v1/employees", params: { department_id: department.id }
      expect(response.parsed_body["data"].map { |r| r["employee_code"] }).to eq([ "EMP00001" ])

      get "/api/v1/employees", params: { employment_status: "exited", include_archived: true }
      expect(response.parsed_body["data"].map { |r| r["employee_code"] }).to eq([ "EMP00003" ])
    end

    it "paginates with per_page capped at 100" do
      get "/api/v1/employees", params: { per_page: 2, page: 2 }
      expect(response.parsed_body["data"].size).to eq(1)
      expect(response.parsed_body["meta"]).to include("page" => 2, "per_page" => 2, "total_pages" => 2)

      get "/api/v1/employees", params: { per_page: 500 }
      expect(response.parsed_body["meta"]["per_page"]).to eq(100)
    end

    it "returns the current salary as a string per employee" do
      employee = Employee.find_by(employee_code: "EMP00001")
      create(:salary_revision, employee: employee, effective_date: Date.new(2021, 1, 1), base_amount: BigDecimal("125000.5"))

      get "/api/v1/employees", params: { q: "EMP00001" }
      row = response.parsed_body["data"].first
      expect(row["current_salary"]).to eq("125000.50")
      expect(row["current_currency"]).to eq("INR")
    end

    it "uses a fixed number of queries regardless of page size" do
      queries = []
      callback = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" || payload[:cached] }

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { get "/api/v1/employees" }
      few = queries.size

      queries.clear
      30.times { |i| create(:employee, employee_code: format("BULK%04d", i), work_email: "bulk#{i}@example.test") }
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { get "/api/v1/employees", params: { per_page: 100 } }

      expect(queries.size).to eq(few)
    end
  end

  describe "GET /api/v1/employees/:id" do
    it "returns the employee with the current salary summary" do
      employee = create(:employee)
      create(:salary_revision, employee: employee, effective_date: Date.new(2021, 1, 1))

      get "/api/v1/employees/#{employee.id}"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "current_salary")).to eq("100000.00")
    end

    it "returns 404 for an unknown id" do
      get "/api/v1/employees/999999"
      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body.dig("error", "code")).to eq("not_found")
    end
  end

  describe "PATCH /api/v1/employees/:id" do
    let!(:employee) { create(:employee, full_name: "Before") }

    it "updates editable fields" do
      patch "/api/v1/employees/#{employee.id}", params: { full_name: "After" }, as: :json
      expect(response).to have_http_status(:ok)
      expect(employee.reload.full_name).to eq("After")
    end

    it "refuses to change the employee code" do
      patch "/api/v1/employees/#{employee.id}", params: { employee_code: "CHANGED" }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(employee.reload.employee_code).not_to eq("CHANGED")
    end

    it "rejects a joining date that conflicts with an existing revision and lists the revision" do
      create(:salary_revision, employee: employee, effective_date: Date.new(2021, 6, 1))
      patch "/api/v1/employees/#{employee.id}", params: { joining_date: "2021-07-01" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      details = response.parsed_body.dig("error", "details")
      expect(details.map { |d| d["field"] }).to include("joining_date")
      expect(details.first["revision_effective_date"]).to eq("2021-06-01")
    end
  end

  describe "archive and unarchive" do
    it "archives an exited employee" do
      employee = create(:employee, :exited)
      post "/api/v1/employees/#{employee.id}/archive"
      expect(response).to have_http_status(:ok)
      expect(employee.reload).to be_archived
    end

    it "refuses to archive an active employee" do
      employee = create(:employee)
      post "/api/v1/employees/#{employee.id}/archive"
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("not_exited")
      expect(employee.reload).not_to be_archived
    end

    it "restores an archived employee" do
      employee = create(:employee, :exited)
      employee.archive!
      post "/api/v1/employees/#{employee.id}/unarchive"
      expect(response).to have_http_status(:ok)
      expect(employee.reload).not_to be_archived
    end
  end

  describe "reference data" do
    it "lists departments, designations, countries, and enabled currencies" do
      department
      designation
      country
      create(:currency, code: "USD", name: "US Dollar", minor_units: 2, enabled: true)
      create(:currency, code: "CHF", name: "Swiss Franc", minor_units: 2, enabled: false)

      get "/api/v1/departments"
      expect(response.parsed_body["data"].map { |d| d["name"] }).to include("Engineering")

      get "/api/v1/designations"
      expect(response.parsed_body["data"].map { |d| d["name"] }).to include("Engineer")

      get "/api/v1/countries"
      expect(response.parsed_body["data"].map { |c| c["code"] }).to include("IN")

      get "/api/v1/currencies"
      codes = response.parsed_body["data"].map { |c| c["code"] }
      expect(codes).to include("USD")
      expect(codes).not_to include("CHF")
    end
  end
end
