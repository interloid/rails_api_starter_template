require "rails_helper"

# The critical auth security test: refresh-token rotation with reuse detection.
RSpec.describe "Refresh token rotation", type: :request do
  let(:user) { create(:user, :confirmed, password: "Password123!") }

  def login_refresh_token
    post_json "/api/v1/auth/login", params: { email: user.email, password: "Password123!" }
    json_body["data"]["refresh_token"]
  end

  it "rotates the token, detects replay, and revokes the whole family" do
    old_token = login_refresh_token

    # 1. Refresh: old token is revoked, a NEW one is returned.
    post_json "/api/v1/auth/refresh", params: { refresh_token: old_token }
    expect(response).to have_http_status(:ok)
    new_token = json_body["data"]["refresh_token"]
    expect(new_token).to be_present
    expect(new_token).not_to eq(old_token)
    expect(RefreshToken.find_by_raw(old_token).revoked_at).to be_present

    # 2. Replaying the OLD (already-revoked) token -> token_reuse_detected.
    post_json "/api/v1/auth/refresh", params: { refresh_token: old_token }
    expect(response).to have_http_status(:unauthorized)
    expect(json_body["error_code"]).to eq("token_reuse_detected")

    # 3. After reuse detection the NEW token is also dead (family revoked).
    post_json "/api/v1/auth/refresh", params: { refresh_token: new_token }
    expect(response).to have_http_status(:unauthorized)

    # 4. In the DB every token in the family has revoked_at set.
    family_id = RefreshToken.find_by_raw(new_token).family_id
    expect(RefreshToken.where(family_id: family_id, revoked_at: nil)).to be_empty
  end
end
