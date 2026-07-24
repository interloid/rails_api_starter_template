require "rails_helper"

RSpec.describe "Account lockout", type: :request do
  let(:user) { create(:user, :confirmed, password: "Password123!") }

  def attempt_login(password)
    post_json "/api/v1/auth/login", params: { email: user.email, password: password }
  end

  it "locks after MAX_FAILED_ATTEMPTS and unlocks after LOCK_DURATION" do
    # The first MAX_FAILED_ATTEMPTS failures each report invalid_credentials.
    User::MAX_FAILED_ATTEMPTS.times do
      attempt_login("wrong")
      expect(response).to have_http_status(:unauthorized)
      expect(json_body["error_code"]).to eq("invalid_credentials")
    end

    # Lock state is now checked only AFTER credentials are proven (H3): a WRONG password
    # against a locked account still returns invalid_credentials — it must not leak the
    # lock. The lock is observable only by supplying the CORRECT password.
    attempt_login("wrong")
    expect(response).to have_http_status(:unauthorized)
    expect(json_body["error_code"]).to eq("invalid_credentials")

    attempt_login("Password123!")
    expect(response).to have_http_status(:forbidden)
    expect(json_body["error_code"]).to eq("account_locked")

    # After the lock window passes, correct credentials succeed and reset the counter.
    travel_to(User::LOCK_DURATION.from_now + 1.second) do
      attempt_login("Password123!")
      expect(response).to have_http_status(:ok)
    end
    expect(user.reload.failed_attempts).to eq(0)
    expect(user.locked_at).to be_nil
  end
end
