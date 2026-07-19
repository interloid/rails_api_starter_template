require "rails_helper"

# B5: a malformed JSON body must return the JSON error envelope, not Rails' default
# 400 error page (ActionDispatch::Http::Parameters::ParseError leaking through).
RSpec.describe "Malformed request handling", type: :request do
  it "returns the error envelope for a malformed JSON body" do
    post "/api/v1/auth/login", params: "{bad json", headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:bad_request)
    expect(json_body["success"]).to be(false)
    expect(json_body["error_code"]).to eq("malformed_json")
  end
end
