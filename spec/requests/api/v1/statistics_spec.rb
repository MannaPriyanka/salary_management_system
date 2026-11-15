require "rails_helper"

RSpec.describe "Statistics API", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:password) { "correct horse battery staple" }
  let(:hr) { create(:user, password: password) }

  before do
    travel_to Time.zone.local(2026, 11, 15, 10, 0, 0)
    post "/api/v1/session", params: { email: hr.email, password: password }, as: :json
    employee = create(:employee, joining_date: Date.new(2020, 1, 1))
    create(:salary_revision, employee: employee, base_amount: BigDecimal("100000.00"), effective_date: Date.new(2021, 1, 1))
  end

  after { travel_back }

  it "requires sign-in" do
    delete "/api/v1/session"
    get "/api/v1/statistics/summary"
    expect(response).to have_http_status(:unauthorized)
  end

  it "returns the summary per currency with amounts as strings" do
    get "/api/v1/statistics/summary"

    expect(response).to have_http_status(:ok)
    row = response.parsed_body["data"].first
    expect(row).to include("currency" => "INR", "headcount" => 1, "total_base" => "100000.00", "as_of" => "2026-11-15")
  end

  it "returns a breakdown by one dimension" do
    get "/api/v1/statistics/breakdown", params: { by: "department" }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["data"].first["group"]).to include("name")
  end

  it "returns 422 for an unknown breakdown dimension" do
    get "/api/v1/statistics/breakdown", params: { by: "salary" }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.dig("error", "code")).to eq("invalid_breakdown")
  end
end
