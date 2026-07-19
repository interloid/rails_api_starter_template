require "rails_helper"

RSpec.describe "Password reset security", type: :request do
  let(:user) { create(:user, :confirmed, password: "OldPassword123!") }

  it "revokes ALL active refresh tokens for the user" do
    active = Array.new(3) { RefreshToken.issue!(user: user).first }
    token = user.generate_token_for(:password_reset)

    post_json "/api/v1/account/reset_password", params: { token: token, password: "NewPassword123!" }
    expect(response).to have_http_status(:ok)

    active.each { |t| expect(t.reload.revoked_at).to be_present }
  end

  it "makes the reset token single-use (it is bound to password_salt)" do
    token = user.generate_token_for(:password_reset)

    post_json "/api/v1/account/reset_password", params: { token: token, password: "NewPassword123!" }
    expect(response).to have_http_status(:ok)

    # The salt changed with the password, so the same token no longer resolves.
    post_json "/api/v1/account/reset_password", params: { token: token, password: "Another123!" }
    expect(response).to have_http_status(422)
    expect(json_body["error_code"]).to eq("invalid_token")
  end
end
