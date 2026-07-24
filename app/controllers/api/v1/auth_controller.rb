module Api
  module V1
    class AuthController < BaseController
      # Auth flows act on the authenticated user themselves (or create a new account) —
      # there is no per-record policy to enforce, so Pundit's guard does not apply.
      skip_after_action :verify_authorized, raise: false

      # Pre-computed digest so a non-existent email performs the SAME bcrypt work as an
      # existing one. Without it, the missing-user path returns measurably faster and
      # leaks account existence despite the generic error message.
      DUMMY_PASSWORD_COST = ActiveModel::SecurePassword.min_cost ? BCrypt::Engine::MIN_COST : BCrypt::Engine.cost
      DUMMY_PASSWORD_DIGEST = BCrypt::Password.create("timing-equalization-dummy", cost: DUMMY_PASSWORD_COST).freeze

      allow_unauthenticated only: %i[register login refresh]
      # Stricter rate limit on auth endpoints (brute-force protection).
      rate_limit to: 10, within: 1.minute, by: -> { request.remote_ip },
                 with: -> { render_rate_limited }, only: %i[login register refresh],
                 scope: "auth"

      # POST /api/v1/auth/register
      def register
        user = User.new(register_params)
        user.save!   # RecordInvalid -> validation_failed envelope via ExceptionHandler

        # Grant the default role so the new user passes their own permission checks.
        # find_by (not find_by!) so a missing role (unseeded env) doesn't crash registration.
        default_role = Role.find_by(name: ENV.fetch("DEFAULT_USER_ROLE", "member"))
        user.roles << default_role if default_role

        UserMailer.confirmation_email(user, user.generate_token_for(:email_confirmation)).deliver_later
        render_success(UserSerializer.one(user), message: "Registered successfully", status: :created)
      end

      # POST /api/v1/auth/login
      def login
        user = User.kept.find_by(email: params[:email].to_s.strip.downcase)

        authenticated =
          if user
            user.authenticate(params[:password].to_s)
          else
            # Equalize timing; result is always false.
            BCrypt::Password.new(DUMMY_PASSWORD_DIGEST).is_password?(params[:password].to_s)
            false
          end

        unless authenticated
          user&.register_failed_attempt!
          return render_error(message: "Invalid email or password",
                              error_code: "invalid_credentials", status: :unauthorized)
        end

        # Lock state is revealed ONLY after credentials are proven — otherwise it is an
        # account-existence oracle.
        if user.locked?
          return render_error(message: "Account locked. Try again later.",
                              error_code: "account_locked", status: :forbidden)
        end

        # Opt-in email-confirmation gate (default OFF so the template works out of the box).
        if ENV.fetch("REQUIRE_EMAIL_CONFIRMATION", "false") == "true" && !user.confirmed?
          return render_error(message: "Please confirm your email address before logging in",
                              error_code: "email_unconfirmed", status: :forbidden)
        end

        user.reset_failed_attempts!
        user.track_sign_in!(request.remote_ip)
        render_success(issue_tokens(user), message: "Logged in successfully")
      end

      # POST /api/v1/auth/refresh
      def refresh
        raw = params[:refresh_token].to_s
        token = RefreshToken.find_by_raw(raw)

        return unauthorized_refresh if token.nil?

        # REUSE DETECTION: an already-revoked token means the lineage is compromised.
        if token.revoked_at.present?
          token.revoke_family!
          Rails.logger.warn("Refresh token reuse detected for user #{token.user_id}; family revoked")
          return render_error(message: "Token reuse detected. Please log in again.",
                              error_code: "token_reuse_detected", status: :unauthorized)
        end

        return unauthorized_refresh unless token.active?

        user = token.user
        # Rotate atomically: revoke old, issue new in the SAME family.
        new_pair = nil
        ActiveRecord::Base.transaction do
          token.revoke!
          new_pair = issue_tokens(user, family_id: token.family_id)
        end
        render_success(new_pair, message: "Token refreshed")
      end

      # POST /api/v1/auth/logout  (authenticated)
      # With a refresh_token: log out just that device (revoke its family). Without one:
      # log out everywhere (revoke all the user's active tokens).
      def logout
        raw = params[:refresh_token].to_s
        token = raw.present? ? RefreshToken.find_by_raw(raw) : nil

        # Revoke the access token used for THIS request (no-op unless the denylist is on).
        JwtService.revoke_jti!(current_token_payload["jti"], current_token_payload["exp"])

        if token && token.user_id == current_user.id
          token.revoke_family!          # this device only
          message = "Logged out from this device"
        else
          RefreshToken.active.where(user: current_user).update_all(revoked_at: Time.current)
          # Log out everywhere: also invalidate every access token issued before now.
          JwtService.revoke_all_for!(current_user.id)
          message = "Logged out from all devices"
        end

        render_success(nil, message: message)
      end

      # GET /api/v1/auth/me  (authenticated)
      def me
        render_success(UserSerializer.one(current_user), message: "Current user")
      end

      private

      def register_params
        params.permit(:email, :password, :first_name, :last_name)
      end

      def issue_tokens(user, family_id: nil)
        _record, raw_refresh = RefreshToken.issue!(
          user: user, family_id: family_id,
          user_agent: request.user_agent, ip_address: request.remote_ip
        )
        {
          access_token: JwtService.encode_access(user),
          refresh_token: raw_refresh,
          token_type: "Bearer",
          expires_in: JwtService::ACCESS_TTL.to_i,
          user: UserSerializer.one(user)
        }
      end

      def unauthorized_refresh
        render_error(message: "Invalid or expired refresh token",
                     error_code: "invalid_refresh_token", status: :unauthorized)
      end
    end
  end
end
