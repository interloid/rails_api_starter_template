require "rails_helper"

# Logout revokes only the presented token's family (this device) when a refresh_token
# is supplied; otherwise it revokes all active tokens (log out everywhere).
RSpec.describe "Per-device logout", type: :request do
  let(:user) { create(:user) }

  it "revokes only the presented token's family when a refresh_token is given" do
    token_a, raw_a = RefreshToken.issue!(user: user) # separate family
    token_b, = RefreshToken.issue!(user: user)       # separate family

    post_json "/api/v1/auth/logout",
              params: { refresh_token: raw_a },
              headers: { "Authorization" => auth_header_for(user) }

    expect(response).to have_http_status(:ok)
    expect(json_body["message"]).to eq("Logged out from this device")
    expect(token_a.reload.revoked_at).to be_present # this device revoked
    expect(token_b.reload.revoked_at).to be_nil     # other device still active
  end

  it "revokes all active tokens when no refresh_token is given" do
    token_a = RefreshToken.issue!(user: user).first
    token_b = RefreshToken.issue!(user: user).first

    post_json "/api/v1/auth/logout", params: {},
              headers: { "Authorization" => auth_header_for(user) }

    expect(response).to have_http_status(:ok)
    expect(json_body["message"]).to eq("Logged out from all devices")
    expect(token_a.reload.revoked_at).to be_present
    expect(token_b.reload.revoked_at).to be_present
  end
end
