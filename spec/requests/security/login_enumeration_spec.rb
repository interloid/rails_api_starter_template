require "rails_helper"

# Guards against account-enumeration oracles on POST /api/v1/auth/login:
#   (a) state oracle — the lock/confirmation state must never be revealed before the
#       password is proven, or it leaks that an email exists;
#   (b) timing oracle — a non-existent email must perform the same bcrypt work as an
#       existing one, so the two paths are not distinguishable by response time.
RSpec.describe "Login enumeration resistance", type: :request do
  let(:password) { "Password123!" }

  def attempt_login(email:, password:)
    post_json "/api/v1/auth/login", params: { email: email, password: password }
  end

  describe "identical failure for unknown email vs. wrong password" do
    it "returns a byte-identical error body (apart from timestamp/path) and 401 for both" do
      existing = create(:user, :confirmed, password: password)

      attempt_login(email: existing.email, password: "wrong-password")
      wrong_password = json_body
      wrong_password_status = response.status

      attempt_login(email: "does-not-exist@example.com", password: "wrong-password")
      unknown_email = json_body
      unknown_email_status = response.status

      expect(wrong_password_status).to eq(401)
      expect(unknown_email_status).to eq(401)
      expect(wrong_password["error_code"]).to eq("invalid_credentials")
      expect(unknown_email["error_code"]).to eq("invalid_credentials")
      expect(wrong_password["message"]).to eq(unknown_email["message"])

      # Everything except per-request volatile fields must match exactly. correlation_id
      # is a fresh trace id per request, so it legitimately differs between the two calls.
      volatile = %w[timestamp path correlation_id]
      expect(wrong_password.except(*volatile)).to eq(unknown_email.except(*volatile))
    end
  end

  describe "lock state is not leaked" do
    it "returns invalid_credentials (not account_locked) for a locked account + wrong password" do
      user = create(:user, :locked, :confirmed, password: password)
      attempt_login(email: user.email, password: "wrong-password")

      expect(response).to have_http_status(:unauthorized)
      expect(json_body["error_code"]).to eq("invalid_credentials")
    end

    it "reveals account_locked only once the correct password is supplied" do
      user = create(:user, :locked, :confirmed, password: password)
      attempt_login(email: user.email, password: password)

      expect(response).to have_http_status(:forbidden)
      expect(json_body["error_code"]).to eq("account_locked")
    end
  end

  describe "timing equalization" do
    it "runs the dummy bcrypt comparison for a non-existent email" do
      # Asserting the code path (not wall-clock) keeps this deterministic: the nil-user
      # branch MUST exercise bcrypt against the pre-computed dummy digest.
      allow(BCrypt::Password).to receive(:new).and_call_original

      attempt_login(email: "nobody@example.com", password: "anything")

      expect(response).to have_http_status(:unauthorized)
      expect(BCrypt::Password).to have_received(:new)
        .with(Api::V1::AuthController::DUMMY_PASSWORD_DIGEST)
    end
  end
end
