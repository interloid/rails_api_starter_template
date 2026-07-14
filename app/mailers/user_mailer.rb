class UserMailer < ApplicationMailer
  def confirmation_email(user, token)
    @url = "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/confirm-email?token=#{token}"
    mail(to: user.email, subject: "Confirm your email")
  end

  def password_reset_email(user, token)
    @url = "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/reset-password?token=#{token}"
    mail(to: user.email, subject: "Reset your password")
  end
end
