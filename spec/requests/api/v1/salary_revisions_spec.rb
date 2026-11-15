require "rails_helper"

RSpec.describe "Salary revisions API", type: :request do
  let(:password) { "correct horse battery staple" }
  let(:hr) { create(:user, password: password) }
  let(:employee) { create(:employee, joining_date: Date.new(2020, 1, 1)) }

  def revision_path = "/api/v1/employees/#{employee.id}/salary_revisions"

  def revision_params(overrides = {})
    {
      currency: "INR",
      base_amount: "125000.50",
      effective_date: "2021-04-01",
      reason: "Annual review",
      components: []
    }.merge(overrides)
  end

  before do
    create(:currency, code: "USD", name: "US Dollar", minor_units: 2, enabled: true)
    post "/api/v1/session", params: { email: hr.email, password: password }, as: :json
  end

  describe "POST revisions" do
    it "records a revision with components and returns amounts as strings" do
      post revision_path, params: revision_params(components: [ { type: "allowance", amount: "5000.00", currency: "INR" } ]), as: :json

      expect(response).to have_http_status(:created)
      data = response.parsed_body["data"]
      expect(data["base_amount"]).to eq("125000.50")
      expect(data["currency"]).to eq("INR")
      expect(data["components"]).to eq([ { "type" => "allowance", "amount" => "5000.00", "currency" => "INR" } ])
      expect(data["recorded_by"]).to eq("id" => hr.id, "email" => hr.email)
    end

    it "accepts a revision in a different currency than the previous one" do
      post revision_path, params: revision_params(effective_date: "2021-01-01"), as: :json
      post revision_path, params: revision_params(currency: "USD", base_amount: "2500.00", effective_date: "2022-01-01"), as: :json

      expect(response).to have_http_status(:created)
      expect(employee.salary_revisions.order(:effective_date).pluck(:currency_code)).to eq(%w[INR USD])
    end

    it "rejects a JSON number for the amount" do
      post revision_path, params: revision_params(base_amount: 125000.5), as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "details", 0, "field")).to eq("base_amount")
    end

    it "rejects an amount with too many decimal places and does not round it" do
      post revision_path, params: revision_params(base_amount: "1000.005"), as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(SalaryRevision.count).to eq(0)
    end

    it "rejects a revision before the joining date" do
      post revision_path, params: revision_params(effective_date: "2019-12-31"), as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "details", 0, "message")).to include("joining date")
    end

    it "rejects a currency that is not enabled" do
      create(:currency, code: "CHF", name: "Swiss Franc", minor_units: 2, enabled: false)
      post revision_path, params: revision_params(currency: "CHF"), as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns 409 when a revision already exists for that effective date" do
      post revision_path, params: revision_params, as: :json
      post revision_path, params: revision_params(base_amount: "130000.00"), as: :json

      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body.dig("error", "code")).to eq("effective_date_conflict")
      expect(SalaryRevision.count).to eq(1)
    end

    it "rejects a component in a different currency from the revision" do
      post revision_path, params: revision_params(components: [ { type: "bonus", amount: "100.00", currency: "USD" } ]), as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(SalaryRevision.count).to eq(0)
    end

    it "rejects an unknown component type and leaves nothing behind" do
      post revision_path, params: revision_params(components: [ { type: "stock", amount: "100.00", currency: "INR" } ]), as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(RevisionComponent.count).to eq(0)
      expect(SalaryRevision.count).to eq(0)
    end

    it "refuses a revision for an unknown employee" do
      post "/api/v1/employees/999999/salary_revisions", params: revision_params, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET revisions" do
    before do
      create(:salary_revision, employee: employee, effective_date: Date.new(2022, 1, 1))
      create(:salary_revision, employee: employee, effective_date: Date.new(2021, 1, 1))
    end

    it "returns history in effective-date order by default" do
      get revision_path
      expect(response.parsed_body["data"].map { |r| r["effective_date"] }).to eq(%w[2021-01-01 2022-01-01])
    end

    it "returns history newest first when asked" do
      get revision_path, params: { order: "effective_desc" }
      expect(response.parsed_body["data"].map { |r| r["effective_date"] }).to eq(%w[2022-01-01 2021-01-01])
    end

    it "returns history for an archived employee" do
      exited = create(:employee, :exited, joining_date: Date.new(2020, 1, 1))
      create(:salary_revision, employee: exited, effective_date: Date.new(2021, 1, 1))
      exited.archive!

      get "/api/v1/employees/#{exited.id}/salary_revisions"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"].size).to eq(1)
    end
  end

  describe "append-only" do
    it "has no route to change or delete a revision" do
      revision = create(:salary_revision, employee: employee)
      patch "/api/v1/employees/#{employee.id}/salary_revisions/#{revision.id}", params: {}, as: :json
      expect(response).to have_http_status(:not_found)

      delete "/api/v1/employees/#{employee.id}/salary_revisions/#{revision.id}"
      expect(response).to have_http_status(:not_found)
      expect(revision.reload.base_amount).to eq(BigDecimal("100000.00"))
    end
  end

  describe "audit trail" do
    it "records who created the employee and each revision" do
      post "/api/v1/employees", params: {
        employee_code: "EMP09001", full_name: "Audit Subject", work_email: "audit.subject@example.test",
        department_id: create(:department).id, designation_id: create(:designation).id,
        country_id: create(:country).id, employment_status: "active", joining_date: "2020-01-01"
      }, as: :json
      new_id = response.parsed_body.dig("data", "id")

      post "/api/v1/employees/#{new_id}/salary_revisions", params: revision_params, as: :json

      get "/api/v1/employees/#{new_id}/audit_entries"
      entries = response.parsed_body["data"]
      expect(entries.map { |e| [ e["entity_type"], e["action"] ] }).to include(%w[Employee create], %w[SalaryRevision create])
      expect(entries.first["actor"]).to eq("id" => hr.id, "email" => hr.email)
    end

    it "records previous and new values when an employee is edited" do
      patch "/api/v1/employees/#{employee.id}", params: { full_name: "Renamed Person" }, as: :json

      get "/api/v1/employees/#{employee.id}/audit_entries"
      update = response.parsed_body["data"].find { |e| e["action"] == "update" }
      expect(update["previous_values"]).to include("full_name" => employee.full_name)
      expect(update["new_values"]).to include("full_name" => "Renamed Person")
    end
  end
end
