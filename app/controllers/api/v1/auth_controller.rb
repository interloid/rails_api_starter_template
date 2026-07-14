module Api
  module V1
    class AuthController < BaseController
      allow_unauthenticated only: %i[register login refresh]
      # Stricter rate limit on auth endpoints (brute-force protection).
      rate_limit to: 10, within: 1.minute, by: -> { request.remote_ip },
                 with: -> { render_rate_limited }, only: %i[login register refresh],
                 scope: "auth"

      # POST /api/v1/auth/register
      def register
        user = User.new(register_params)
        user.save!   # RecordInvalid -> validation_failed envelope via ExceptionHandler
        UserMailer.confirmation_email(user, user.generate_token_for(:email_confirmation)).deliver_later
        render_success(UserSerializer.one(user), message: "Registered successfully", status: :created)
      end

      # POST /api/v1/auth/login
      def login
        user = User.kept.find_by(email: params[:email].to_s.strip.downcase)

        if user&.locked?
          return render_error(message: "Account locked. Try again later.",
                              error_code: "account_locked", status: :forbidden)
        end

        # Generic message on failure — prevents email enumeration.
        unless user&.authenticate(params[:password].to_s)
          user&.register_failed_attempt!
          return render_error(message: "Invalid email or password",
                              error_code: "invalid_credentials", status: :unauthorized)
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
      def logout
        RefreshToken.active.where(user: current_user).update_all(revoked_at: Time.current)
        render_success(nil, message: "Logged out successfully")
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
