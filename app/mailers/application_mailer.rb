class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "no-reply@example.com")
  layout nil   # API app: plain text only, no HTML layouts
end
