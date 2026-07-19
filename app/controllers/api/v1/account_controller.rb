module Api
  module V1
    class AccountController < BaseController
      # All actions are public, token/email-scoped self-service (confirm, reset, resend) —
      # they resolve the target user from a token/email, not a record-level policy.
      skip_after_action :verify_authorized, raise: false

      allow_unauthenticated only: %i[confirm_email forgot_password reset_password resend_confirmation]

      # Brute-force protection on these public, email-triggering endpoints.
      rate_limit to: 5, within: 1.minute, by: -> { request.remote_ip },
                 with: -> { render_rate_limited },
                 only: %i[forgot_password resend_confirmation]

      # POST /api/v1/account/confirm_email  { token }
      def confirm_email
        user = User.find_by_token_for(:email_confirmation, params[:token].to_s)
        return invalid_token if user.nil?
        return render_success(nil, message: "Email already confirmed") if user.confirmed?

        user.confirm!
        render_success(nil, message: "Email confirmed successfully")
      end

      # POST /api/v1/account/resend_confirmation  { email }
      def resend_confirmation
        user = User.kept.find_by(email: params[:email].to_s.strip.downcase)
        if user && !user.confirmed?
          UserMailer.confirmation_email(user, user.generate_token_for(:email_confirmation)).deliver_later
        end
        # Always the same response — never reveal whether the email exists.
        render_success(nil, message: "If that account exists and is unconfirmed, a confirmation email has been sent")
      end

      # POST /api/v1/account/forgot_password  { email }
      def forgot_password
        user = User.kept.find_by(email: params[:email].to_s.strip.downcase)
        if user
          UserMailer.password_reset_email(user, user.generate_token_for(:password_reset)).deliver_later
        end
        # Same response either way — prevents email enumeration.
        render_success(nil, message: "If that account exists, a password reset email has been sent")
      end

      # POST /api/v1/account/reset_password  { token, password }
      def reset_password
        user = User.find_by_token_for(:password_reset, params[:token].to_s)
        return invalid_token if user.nil?

        user.password = params[:password].to_s
        user.save!   # RecordInvalid -> validation_failed envelope

        # SECURITY: a password reset must kill every existing session.
        RefreshToken.active.where(user: user).update_all(revoked_at: Time.current)
        user.reset_failed_attempts!   # also unlocks a locked account

        render_success(nil, message: "Password reset successfully. Please log in again.")
      end

      private

      def invalid_token
        render_error(message: "Invalid or expired token", error_code: "invalid_token",
                     status: :unprocessable_entity)
      end
    end
  end
end
