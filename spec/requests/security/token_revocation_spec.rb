require "rails_helper"

# Opt-in access-token revocation (JWT_DENYLIST_ENABLED). By default access JWTs are
# stateless and valid for their full TTL; with the flag on, logout / password-reset push
# the token (or a user-wide cutoff) into a Rails.cache denylist that decode consults.
RSpec.describe "Access-token revocation", type: :request do
  let(:user) { create(:user, :confirmed) }

  # The test env uses :null_store (writes are dropped), so the denylist can't work there.
  # Swap in a real memory store for these examples only.
  around do |example|
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
    Rails.cache = original
  end

  context "when the denylist is OFF (default)" do
    it "keeps the access token valid after logout — stateless behaviour preserved" do
      token = access_token_for(user)
      refresh = RefreshToken.issue!(user: user).last

      post_json "/api/v1/auth/logout",
                params: { refresh_token: refresh },
                headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(:ok)

      get "/api/v1/auth/me", headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(:ok)
    end
  end

  context "when the denylist is ON" do
    before { stub_const("JwtService::DENYLIST_ENABLED", -> { true }) }

    it "revokes the CURRENT access token on logout (this device)" do
      token = access_token_for(user)
      refresh = RefreshToken.issue!(user: user).last

      post_json "/api/v1/auth/logout",
                params: { refresh_token: refresh },
                headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(:ok)

      get "/api/v1/auth/me", headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(:unauthorized)
      expect(json_body["errors"].first["message"]).to include("revoked")
    end

    it "revokes OTHER access tokens for the same user on logout-everywhere" do
      # Issued before the logout cutoff, so it falls under the user-wide revocation.
      other_token = travel_to(10.seconds.ago) { access_token_for(user) }
      logout_token = access_token_for(user)

      post_json "/api/v1/auth/logout", # no refresh_token => log out everywhere
                params: {},
                headers: { "Authorization" => "Bearer #{logout_token}" }
      expect(response).to have_http_status(:ok)

      get "/api/v1/auth/me", headers: { "Authorization" => "Bearer #{other_token}" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "revokes all access tokens for the user on password reset" do
      token = travel_to(10.seconds.ago) { access_token_for(user) }
      reset_token = user.generate_token_for(:password_reset)

      post_json "/api/v1/account/reset_password",
                params: { token: reset_token, password: "BrandNew123!" }
      expect(response).to have_http_status(:ok)

      get "/api/v1/auth/me", headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "still accepts a token issued AFTER a logout-everywhere cutoff" do
      old_token = travel_to(10.seconds.ago) { access_token_for(user) }

      post_json "/api/v1/auth/logout",
                params: {},
                headers: { "Authorization" => "Bearer #{old_token}" }
      expect(response).to have_http_status(:ok)

      fresh_token = access_token_for(user)
      get "/api/v1/auth/me", headers: { "Authorization" => "Bearer #{fresh_token}" }
      expect(response).to have_http_status(:ok)
    end
  end
end
