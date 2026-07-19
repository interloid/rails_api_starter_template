require "rails_helper"

# Opt-in email-confirmation gate at login (REQUIRE_EMAIL_CONFIRMATION, default off).
RSpec.describe "Login email-confirmation gate", type: :request do
  let(:user) { create(:user, password: "Password123!") } # unconfirmed by default

  def login
    post_json "/api/v1/auth/login", params: { email: user.email, password: "Password123!" }
  end

  context "when the flag is off (default)" do
    it "lets an unconfirmed user log in" do
      login
      expect(response).to have_http_status(:ok)
      expect(json_body["data"]).to include("access_token")
    end
  end

  context "when the flag is on" do
    around do |example|
      original = ENV["REQUIRE_EMAIL_CONFIRMATION"]
      ENV["REQUIRE_EMAIL_CONFIRMATION"] = "true"
      example.run
      ENV["REQUIRE_EMAIL_CONFIRMATION"] = original
    end

    it "blocks an unconfirmed user with 403 email_unconfirmed" do
      login
      expect(response).to have_http_status(:forbidden)
      expect(json_body["error_code"]).to eq("email_unconfirmed")
    end

    it "still allows a confirmed user" do
      user.confirm!
      login
      expect(response).to have_http_status(:ok)
      expect(json_body["data"]).to include("access_token")
    end
  end
end
