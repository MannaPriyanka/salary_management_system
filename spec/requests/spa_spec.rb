require "rails_helper"
require "tempfile"

RSpec.describe "Web app delivery", type: :request do
  let(:index_file) do
    Tempfile.new([ "index", ".html" ]).tap do |file|
      file.write("<!doctype html><title>ACME Salary Management</title>")
      file.flush
    end
  end

  before do
    allow(SpaController).to receive(:index_path).and_return(Pathname.new(index_file.path))
  end

  after { index_file.close! }

  it "serves the web app for the root path" do
    get "/"
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/html")
    expect(response.body).to include("ACME Salary Management")
  end

  it "serves the web app for client-side routes so a browser refresh works" do
    get "/employees/42"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("ACME Salary Management")
  end

  it "answers unknown API paths with JSON, never with the web app" do
    get "/api/v1/does-not-exist"
    expect(response).to have_http_status(:not_found)
    expect(response.media_type).to eq("application/json")
  end

  it "explains when the web app has not been built" do
    allow(SpaController).to receive(:index_path).and_return(Rails.root.join("tmp", "missing-index.html"))
    get "/employees"
    expect(response).to have_http_status(:not_found)
    expect(response.parsed_body.dig("error", "code")).to eq("frontend_not_built")
  end
end
