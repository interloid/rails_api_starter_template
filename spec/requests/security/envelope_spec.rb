require "rails_helper"

RSpec.describe "Response envelope", type: :request do
  let(:user) { create(:user, :confirmed, password: "Password123!") }

  it "wraps a success in the fixed envelope with data and NO errors key" do
    post_json "/api/v1/auth/login", params: { email: user.email, password: "Password123!" }

    expect(json_body.keys).to include("success", "status_code", "message", "data", "timestamp", "path")
    expect(json_body).not_to have_key("errors")
    expect(json_body["success"]).to be true
  end

  it "wraps an error in the fixed envelope with errors and NO data key" do
    post_json "/api/v1/auth/login", params: { email: user.email, password: "wrong" }

    expect(json_body.keys).to include("success", "status_code", "error_code", "message", "errors", "timestamp", "path")
    expect(json_body).not_to have_key("data")
    expect(json_body["success"]).to be false
  end

  it "returns the catch-all 404 envelope for an unknown route" do
    get "/api/v1/this-route-does-not-exist"

    expect(response).to have_http_status(:not_found)
    expect(json_body["error_code"]).to eq("not_found")
  end

  describe "correlation id" do
    it "echoes an inbound X-Correlation-ID unchanged" do
      get "/api/v1/status", headers: { "X-Correlation-ID" => "trace-abc-123" }
      expect(response.headers["X-Correlation-ID"]).to eq("trace-abc-123")
    end

    it "generates one when the client sends none" do
      get "/api/v1/status"
      expect(response.headers["X-Correlation-ID"]).to be_present
    end

    it "includes the correlation_id in an error body, matching the response header" do
      get "/api/v1/auth/me" # 401 — no token

      expect(response).to have_http_status(:unauthorized)
      expect(json_body["correlation_id"]).to be_present
      expect(json_body["correlation_id"]).to eq(response.headers["X-Correlation-ID"])
    end

    it "surfaces a client-supplied X-Correlation-ID in the error body" do
      get "/api/v1/auth/me", headers: { "X-Correlation-ID" => "trace-err-999" }

      expect(response).to have_http_status(:unauthorized)
      expect(json_body["correlation_id"]).to eq("trace-err-999")
    end
  end
end
