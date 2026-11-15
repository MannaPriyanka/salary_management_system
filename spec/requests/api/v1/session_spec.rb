require "rails_helper"

RSpec.describe "Session API", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:password) { "correct horse battery staple" }
  let!(:hr_manager) { create(:user, email: "hr@example.test", password: password) }

  before { Rails.cache.clear }

  describe "POST /api/v1/session" do
    it "signs in with valid credentials and returns the user" do
      post "/api/v1/session", params: { email: "hr@example.test", password: password }, as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["data"]).to include("email" => "hr@example.test")
      expect(response.parsed_body["data"]).not_to have_key("password_digest")
    end

    it "returns the same generic error for a wrong password and an unknown email" do
      post "/api/v1/session", params: { email: "hr@example.test", password: "wrong password here" }, as: :json
      wrong_password = response.parsed_body

      post "/api/v1/session", params: { email: "nobody@example.test", password: "wrong password here" }, as: :json
      unknown_email = response.parsed_body

      expect(response).to have_http_status(:unauthorized)
      expect(unknown_email).to eq(wrong_password)
      expect(wrong_password.dig("error", "code")).to eq("invalid_credentials")
    end

    it "treats email case-insensitively" do
      post "/api/v1/session", params: { email: "  HR@Example.TEST ", password: password }, as: :json
      expect(response).to have_http_status(:created)
    end

    it "refuses sign-in for 15 minutes after 5 failures, then allows it again" do
      5.times { post "/api/v1/session", params: { email: "hr@example.test", password: "nope nope nope" }, as: :json }
      expect(response).to have_http_status(:unauthorized)

      post "/api/v1/session", params: { email: "hr@example.test", password: password }, as: :json
      expect(response).to have_http_status(:too_many_requests)
      expect(response.headers["Retry-After"].to_i).to be_between(1, 900)
      expect(response.parsed_body.dig("error", "code")).to eq("sign_in_refused")

      travel 15.minutes + 1.second do
        post "/api/v1/session", params: { email: "hr@example.test", password: password }, as: :json
        expect(response).to have_http_status(:created)
      end
    end

    it "refuses unknown accounts the same way, so throttling does not reveal which emails exist" do
      5.times { post "/api/v1/session", params: { email: "ghost@example.test", password: "nope nope nope" }, as: :json }

      post "/api/v1/session", params: { email: "ghost@example.test", password: "nope nope nope" }, as: :json
      throttled_unknown = response.parsed_body

      expect(response).to have_http_status(:too_many_requests)
      expect(throttled_unknown.dig("error", "code")).to eq("sign_in_refused")
    end

    it "clears the failure count after a successful sign-in" do
      4.times { post "/api/v1/session", params: { email: "hr@example.test", password: "nope nope nope" }, as: :json }
      post "/api/v1/session", params: { email: "hr@example.test", password: password }, as: :json
      expect(response).to have_http_status(:created)

      4.times { post "/api/v1/session", params: { email: "hr@example.test", password: "nope nope nope" }, as: :json }
      expect(response).to have_http_status(:unauthorized)
    end

    it "does not count failures as a permanent lock: the failure window expires" do
      4.times { post "/api/v1/session", params: { email: "hr@example.test", password: "nope nope nope" }, as: :json }
      travel 16.minutes do
        post "/api/v1/session", params: { email: "hr@example.test", password: "nope nope nope" }, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/session" do
    it "returns 401 when not signed in" do
      get "/api/v1/session"
      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body.dig("error", "code")).to eq("not_signed_in")
    end

    it "returns the current user after sign-in" do
      post "/api/v1/session", params: { email: "hr@example.test", password: password }, as: :json
      get "/api/v1/session"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "email")).to eq("hr@example.test")
    end
  end

  describe "DELETE /api/v1/session" do
    it "signs out so later requests are refused" do
      post "/api/v1/session", params: { email: "hr@example.test", password: password }, as: :json
      delete "/api/v1/session"
      expect(response).to have_http_status(:no_content)

      get "/api/v1/session"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PUT /api/v1/session/password" do
    before { post "/api/v1/session", params: { email: "hr@example.test", password: password }, as: :json }

    it "changes the password when the current one is correct" do
      put "/api/v1/session/password",
          params: { current_password: password, new_password: "a brand new passphrase" }, as: :json
      expect(response).to have_http_status(:no_content)
      expect(hr_manager.reload.authenticate("a brand new passphrase")).to be_truthy
    end

    it "rejects the change when the current password is wrong" do
      put "/api/v1/session/password",
          params: { current_password: "not the password", new_password: "a brand new passphrase" }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("current_password_incorrect")
    end

    it "rejects a new password shorter than 12 characters" do
      put "/api/v1/session/password", params: { current_password: password, new_password: "short" }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("validation_failed")
    end
  end
end
